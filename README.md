# Hooder — Native (iOS 26 / Swift 6 · Liquid Glass)

Hooder gayrimenkul tycoon oyununun **sıfırdan native SwiftUI** yeniden yazımı.
**iOS 26 Liquid Glass**, **mercek yanması** (specular sweep), **ultra yumuşak spring**
animasyonlar, **offline uydu harita** + **canlı mülk pin'leri**. Konum izni **yok**.

## Şu an çalışan (bu temel)
- 🟦 **Liquid Glass design system** — `liquidGlass()` modifier (iOS 26 `.glassEffect`,
  eski iOS'ta materyal fallback) + **SpecularSweep** (yüzeyde gezen parlak kırılma =
  mercek yanması, `TimelineView(.animation)` ile kare-senkron, ultra pürüzsüz).
- 🟦 **Ultra yumuşak hareket** — `Motion` spring presetleri (smooth/glass/press/snappy),
  buton basış scale, `appearIn` liquid giriş, `contentTransition(.numericText)` para sayacı.
- 🛰️ **Offline uydu harita** — `OfflineTileDownloader` (TileStore + OfflineManager +
  TilesetDescriptor + StylePack) açılışta sessiz indirir → uçak modunda açılır.
- 📍 **Canlı mülk pin'leri** — `PropertyMapView` (PointAnnotationManager, `iconAllowOverlap`,
  tap → detay). Harita offline, pin'ler canlı (`PropertyFeed` periyodik).
- 🎮 **Oyun çekirdeği** — `GameState` (@Observable): nakit, satın alma, günlük gelir
  tahakkuku, net değer, kalıcılık (UserDefaults).
- 🧭 **Kabuk** — cam sekme çubuğu (matchedGeometry seçim), HUD, alttan kayan cam panel.
- 🏬 **Piyasa** — liste + arama + **kart-içi satın alma onayı** (popup yok → siyah ekran yok).
- 💼 **Portföy** — sahip olunan mülkler + özet kartları.

## Eklenen katmanlar (tamamlandı)
- 🌍 **Gerçek mülk verisi** — `PropertyService` (Mapbox tilequery + reverse geocode):
  tüm dünyada baktığın bölgenin gerçek POI/binaları satın alınabilir mülke dönüşür,
  kamera durunca otomatik yüklenir, cache'li.
- 🧮 **Yoğunluk → liste + declutter** — `PropertyMapView` ekran merkezine yakın
  mülkleri önce, piksel-aralıkla üst üste binmesin, cap 24; çok yoğunsa marker yok →
  otomatik **alan listesi** sheet'i (kasma yok).
- 🛒 **StoreKit 2 IAP** — `Store` + `StoreScreen`: nakit paketleri, kredi doğrudan
  transaction'dan (2.1(b) güvenli), bitmemiş işlem teslimi.
- 🛰️ **Backend senkron** — `BackendService`: canlı liderlik + açık artırma + teklif +
  skor gönderimi; offline-tolerant (sunucu yoksa yerel mock).
- 🌐 **16 dil** — `L10n` (@Observable) + `t("key")`; Ayarlar'da anlık dil seçici
  (tr/en/es/fr/de/it/pt/ru/ar/zh/ja/ko/az/uk/fa/hi).

## Hâlâ iyileştirilebilir (opsiyonel)
- Tüm string'lerin %100 lokalizasyonu (şu an çekirdek arayüz çevrildi).
- Forex/Döviz ekranı, açık artırma oluşturma, push bildirim, gerçek backend uçları.

## Kurulum (Xcode 26+)
1. **SPM**: `https://github.com/mapbox/mapbox-maps-ios` → Up to Next Major **11.0.0**.
2. **Token**: `Info.plist` → `MBXAccessToken` (public). Secret download token (Downloads:Read)
   → `~/.netrc` (bkz. `Info.plist.snippet.xml`).
3. **Konum anahtarı EKLEME** (GPS sorulmaz).
4. Tüm `.swift` dosyalarını hedefe ekle, `HooderApp` `@main` → çalıştır.

## Dosya haritası
```
HooderApp.swift              @main
Design/Theme.swift           renk/ölçü/tipografi/Motion (spring)
Design/LiquidGlass.swift     glass + SpecularSweep (mercek yanması)
Design/GlassControls.swift   GlassButton, GlassCard, appearIn
Models/Property.swift        mülk modeli
Models/GameState.swift       @Observable oyun durumu (nakit/satın alma/gelir)
Services/PropertyFeed.swift  canlı mülk beslemesi (+ tohum veri)
Map/OfflineTileDownloader.swift  otomatik offline indirme
Map/PropertyMapView.swift    uydu harita + canlı pin'ler
Components/GlassTabBar.swift  cam sekme çubuğu
Components/HUDBar.swift       üst HUD
Screens/RootView.swift       kabuk (harita + panel + sekme)
Screens/MapScreen.swift      harita ekranı
Screens/MarketScreen.swift   piyasa + kart-içi satın alma
Screens/PortfolioScreen.swift portföy
Screens/PropertyDetailSheet.swift mülk detay
```

## Performans notu
`SpecularSweep` her cam yüzeyde `TimelineView(.animation)` kullanır. Çok uzun listelerde
(yüzlerce kart) FPS için sweep'i yalnız görünür/öne çıkan yüzeylere sınırlayabiliriz —
şu an demo amaçlı her yüzeyde açık.
