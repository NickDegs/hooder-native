# Çekilen gerçek simulator ekran görüntülerini App Store'a yükler.
# shots/<ascLocale>/iphone_<tab>.png -> APP_IPHONE_67 (1290x2796)
# shots/<ascLocale>/ipad_<tab>.png   -> APP_IPAD_PRO_3GEN_129 (2048x2732)
import os, time, glob, hashlib, jwt, requests
from PIL import Image

KID=os.environ["ASC_KEY_ID"]; ISS=os.environ["ASC_ISSUER_ID"]
key=open("/tmp/asc.p8").read()
def H():
    return {"Authorization":"Bearer "+jwt.encode({"iss":ISS,"iat":int(time.time()),"exp":int(time.time())+1200,"aud":"appstoreconnect-v1"},key,algorithm="ES256",headers={"kid":KID}),"Content-Type":"application/json"}
B="https://api.appstoreconnect.apple.com/v1"; VID="acdf535d-4d6e-4ded-ad40-bed7ab9db2a3"
SIZES={"iphone":("APP_IPHONE_67",(1290,2796)),"ipad":("APP_IPAD_PRO_3GEN_129",(2048,2732))}
TAB_ORDER={"map":0,"market":1,"forex":2,"store":3,"portfolio":4}

locs={l["attributes"]["locale"]: l["id"] for l in requests.get(B+f"/appStoreVersions/{VID}/appStoreVersionLocalizations?limit=50",headers=H()).json()["data"]}

def set_for(lid, dt):
    sets=requests.get(B+f"/appStoreVersionLocalizations/{lid}/appScreenshotSets?limit=50&include=appScreenshots",headers=H()).json()
    for s in sets.get("data",[]):
        if s["attributes"].get("screenshotDisplayType")==dt:
            for sc in s.get("relationships",{}).get("appScreenshots",{}).get("data",[]):
                requests.delete(B+f"/appScreenshots/{sc['id']}",headers=H())
            return s["id"]
    r=requests.post(B+"/appScreenshotSets",headers=H(),json={"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":dt},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":lid}}}}})
    return r.json()["data"]["id"] if r.status_code<300 else None

def upload(setid, path):
    data=open(path,"rb").read(); sz=len(data); md5=hashlib.md5(data).hexdigest()
    r=requests.post(B+"/appScreenshots",headers=H(),json={"data":{"type":"appScreenshots","attributes":{"fileSize":sz,"fileName":os.path.basename(path)},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":setid}}}}})
    if r.status_code>=300: print("  reserve FAIL",r.status_code,r.text[:120]); return False
    a=r.json()["data"]; sid=a["id"]
    for op in a["attributes"]["uploadOperations"]:
        hdr={h["name"]:h["value"] for h in op.get("requestHeaders",[])}
        requests.request(op["method"],op["url"],headers=hdr,data=data[op["offset"]:op["offset"]+op["length"]])
    c=requests.patch(B+f"/appScreenshots/{sid}",headers=H(),json={"data":{"type":"appScreenshots","id":sid,"attributes":{"uploaded":True,"sourceFileChecksum":md5}}})
    return c.status_code<300

done=fail=0
for loc, lid in locs.items():
    folder=f"shots/{loc}"
    if not os.path.isdir(folder): continue
    for prefix,(dt,target) in SIZES.items():
        files=sorted(glob.glob(f"{folder}/{prefix}_*.png"), key=lambda p: TAB_ORDER.get(os.path.basename(p).split('_')[1].split('.')[0],9))
        if not files: continue
        setid=set_for(lid, dt)
        if not setid: print("SET FAIL",loc,dt); continue
        for p in files[:10]:
            # tam boyuta getir (App Store kesin boyut ister)
            im=Image.open(p).convert("RGB")
            if im.size!=target: im=im.resize(target, Image.LANCZOS)
            im.save(p,"PNG")
            if upload(setid,p): done+=1
            else: fail+=1
    print(f"{loc} bitti (done={done} fail={fail})", flush=True)
print(f"TAMAM yüklenen={done} hata={fail}")
