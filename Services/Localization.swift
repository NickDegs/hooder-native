import Foundation
import Observation

// ── 16 dil lokalizasyon ───────────────────────────────────────────────────────
// L10n.shared.lang değişince @Observable sayesinde tüm View'lar yenilenir.
// t("key") global fonksiyonu ile kullanılır.
@MainActor
@Observable
final class L10n {
    static let shared = L10n()
    static let languages = ["tr","en","es","fr","de","it","pt","ru","ar","zh","ja","ko","az","uk","fa","hi"]
    static let names: [String:String] = [
        "tr":"Türkçe","en":"English","es":"Español","fr":"Français","de":"Deutsch","it":"Italiano",
        "pt":"Português","ru":"Русский","ar":"العربية","zh":"中文","ja":"日本語","ko":"한국어",
        "az":"Azərbaycan","uk":"Українська","fa":"فارسی","hi":"हिन्दी"
    ]

    var lang: String {
        didSet { UserDefaults.standard.set(lang, forKey: "lang") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "lang")
        let sys = Locale.current.language.languageCode?.identifier ?? "en"
        lang = Self.languages.contains(saved ?? "") ? saved! : (Self.languages.contains(sys) ? sys : "en")
    }

    func t(_ key: String) -> String {
        Self.dict[key]?[lang] ?? Self.dict[key]?["en"] ?? key
    }

    static let dict: [String:[String:String]] = [
        "tab_map":       ["tr":"Harita","en":"Map","es":"Mapa","fr":"Carte","de":"Karte","it":"Mappa","pt":"Mapa","ru":"Карта","ar":"خريطة","zh":"地图","ja":"地図","ko":"지도","az":"Xəritə","uk":"Карта","fa":"نقشه","hi":"मानचित्र"],
        "tab_market":    ["tr":"Piyasa","en":"Market","es":"Mercado","fr":"Marché","de":"Markt","it":"Mercato","pt":"Mercado","ru":"Рынок","ar":"السوق","zh":"市场","ja":"市場","ko":"시장","az":"Bazar","uk":"Ринок","fa":"بازار","hi":"बाज़ार"],
        "tab_portfolio": ["tr":"Portföy","en":"Portfolio","es":"Cartera","fr":"Portefeuille","de":"Portfolio","it":"Portafoglio","pt":"Carteira","ru":"Портфель","ar":"المحفظة","zh":"投资组合","ja":"ポート","ko":"포트폴리오","az":"Portfel","uk":"Портфель","fa":"سبد","hi":"पोर्टफोलियो"],
        "tab_store":     ["tr":"Mağaza","en":"Store","es":"Tienda","fr":"Boutique","de":"Shop","it":"Negozio","pt":"Loja","ru":"Магазин","ar":"المتجر","zh":"商店","ja":"ストア","ko":"상점","az":"Mağaza","uk":"Магазин","fa":"فروشگاه","hi":"स्टोर"],
        "tab_rankings":  ["tr":"Sıralama","en":"Ranks","es":"Ranking","fr":"Classement","de":"Rang","it":"Classifica","pt":"Ranking","ru":"Рейтинг","ar":"الترتيب","zh":"排名","ja":"順位","ko":"순위","az":"Reytinq","uk":"Рейтинг","fa":"رتبه","hi":"रैंक"],
        "tab_settings":  ["tr":"Ayarlar","en":"Settings","es":"Ajustes","fr":"Réglages","de":"Einstellungen","it":"Impostazioni","pt":"Ajustes","ru":"Настройки","ar":"الإعدادات","zh":"设置","ja":"設定","ko":"설정","az":"Tənzimləmələr","uk":"Налаштування","fa":"تنظیمات","hi":"सेटिंग्स"],
        "tab_forex":     ["tr":"Döviz","en":"Forex","es":"Divisas","fr":"Devises","de":"Devisen","it":"Valute","pt":"Câmbio","ru":"Форекс","ar":"عملات","zh":"外汇","ja":"為替","ko":"환전","az":"Valyuta","uk":"Форекс","fa":"ارز","hi":"फॉरेक्स"],
        "market_index":  ["tr":"Piyasa Endeksi","en":"Market Index","es":"Índice","fr":"Indice","de":"Marktindex","it":"Indice","pt":"Índice","ru":"Индекс","ar":"المؤشر","zh":"市场指数","ja":"市場指数","ko":"시장 지수","az":"İndeks","uk":"Індекс","fa":"شاخص","hi":"सूचकांक"],
        "sell":          ["tr":"Sat","en":"Sell","es":"Vender","fr":"Vendre","de":"Verkaufen","it":"Vendi","pt":"Vender","ru":"Продать","ar":"بيع","zh":"卖出","ja":"売却","ko":"판매","az":"Sat","uk":"Продати","fa":"فروش","hi":"बेचें"],
        "sold":          ["tr":"satıldı","en":"sold","es":"vendido","fr":"vendu","de":"verkauft","it":"venduto","pt":"vendido","ru":"продано","ar":"بيع","zh":"已售","ja":"売却","ko":"판매됨","az":"satıldı","uk":"продано","fa":"فروخته","hi":"बिका"],
        "cash":          ["tr":"NAKİT","en":"CASH","es":"EFECTIVO","fr":"CASH","de":"BARGELD","it":"CONTANTI","pt":"DINHEIRO","ru":"НАЛИЧНЫЕ","ar":"نقد","zh":"现金","ja":"現金","ko":"현금","az":"NAĞD","uk":"ГОТІВКА","fa":"نقد","hi":"नकद"],
        "investor":      ["tr":"Yatırımcı","en":"Investor","es":"Inversor","fr":"Investisseur","de":"Investor","it":"Investitore","pt":"Investidor","ru":"Инвестор","ar":"مستثمر","zh":"投资者","ja":"投資家","ko":"투자자","az":"İnvestor","uk":"Інвестор","fa":"سرمایه‌گذار","hi":"निवेशक"],
        "buy":           ["tr":"Satın Al","en":"Buy","es":"Comprar","fr":"Acheter","de":"Kaufen","it":"Compra","pt":"Comprar","ru":"Купить","ar":"شراء","zh":"购买","ja":"購入","ko":"구매","az":"Al","uk":"Купити","fa":"خرید","hi":"खरीदें"],
        "cancel":        ["tr":"İptal","en":"Cancel","es":"Cancelar","fr":"Annuler","de":"Abbrechen","it":"Annulla","pt":"Cancelar","ru":"Отмена","ar":"إلغاء","zh":"取消","ja":"キャンセル","ko":"취소","az":"Ləğv","uk":"Скасувати","fa":"لغو","hi":"रद्द"],
        "insufficient":  ["tr":"Yetersiz","en":"Low funds","es":"Sin fondos","fr":"Fonds bas","de":"Zu wenig","it":"Fondi bassi","pt":"Sem fundos","ru":"Мало средств","ar":"رصيد قليل","zh":"余额不足","ja":"残高不足","ko":"잔액 부족","az":"Kifayət deyil","uk":"Мало коштів","fa":"موجودی کم","hi":"अपर्याप्त"],
        "owned":         ["tr":"Sahipsiniz","en":"Owned","es":"En propiedad","fr":"Possédé","de":"Im Besitz","it":"Posseduto","pt":"Possuído","ru":"В собственности","ar":"مملوك","zh":"已拥有","ja":"所有済み","ko":"보유 중","az":"Sizindir","uk":"У власності","fa":"مالک","hi":"स्वामित्व"],
        "search_ph":     ["tr":"Mülk, şehir ara…","en":"Search property, city…","es":"Buscar propiedad, ciudad…","fr":"Bien, ville…","de":"Immobilie, Stadt…","it":"Proprietà, città…","pt":"Imóvel, cidade…","ru":"Объект, город…","ar":"عقار، مدينة…","zh":"搜索房产、城市…","ja":"物件・都市…","ko":"매물, 도시…","az":"Əmlak, şəhər…","uk":"Об'єкт, місто…","fa":"ملک، شهر…","hi":"संपत्ति, शहर…"],
        "net_worth":     ["tr":"Net Değer","en":"Net Worth","es":"Patrimonio","fr":"Valeur nette","de":"Nettowert","it":"Patrimonio","pt":"Patrimônio","ru":"Капитал","ar":"صافي الثروة","zh":"净资产","ja":"純資産","ko":"순자산","az":"Xalis dəyər","uk":"Капітал","fa":"ارزش خالص","hi":"कुल संपत्ति"],
        "daily_income":  ["tr":"Günlük Gelir","en":"Daily Income","es":"Ingreso diario","fr":"Revenu/jour","de":"Tageseinkommen","it":"Reddito/giorno","pt":"Renda diária","ru":"Доход/день","ar":"دخل يومي","zh":"日收入","ja":"日収","ko":"일일 수입","az":"Günlük gəlir","uk":"Дохід/день","fa":"درآمد روزانه","hi":"दैनिक आय"],
        "property_count":["tr":"Mülk Sayısı","en":"Properties","es":"Propiedades","fr":"Biens","de":"Immobilien","it":"Proprietà","pt":"Imóveis","ru":"Объекты","ar":"العقارات","zh":"房产数","ja":"物件数","ko":"매물 수","az":"Əmlak sayı","uk":"Об'єкти","fa":"تعداد املاک","hi":"संपत्तियाँ"],
        "no_props":      ["tr":"Henüz mülkün yok","en":"No properties yet","es":"Aún sin propiedades","fr":"Aucun bien","de":"Noch keine Immobilien","it":"Nessuna proprietà","pt":"Nenhum imóvel","ru":"Пока нет объектов","ar":"لا عقارات بعد","zh":"还没有房产","ja":"物件なし","ko":"보유 매물 없음","az":"Hələ əmlak yoxdur","uk":"Поки немає об'єктів","fa":"هنوز ملکی ندارید","hi":"अभी कोई संपत्ति नहीं"],
        "area_props":    ["tr":"Bu bölgedeki mülkler","en":"Properties here","es":"Propiedades aquí","fr":"Biens ici","de":"Immobilien hier","it":"Proprietà qui","pt":"Imóveis aqui","ru":"Объекты здесь","ar":"عقارات هنا","zh":"此处房产","ja":"このエリアの物件","ko":"이 지역 매물","az":"Buradakı əmlaklar","uk":"Об'єкти тут","fa":"املاک اینجا","hi":"यहाँ की संपत्तियाँ"],
        "cash_packs":    ["tr":"Nakit Paketleri","en":"Cash Packs","es":"Paquetes de efectivo","fr":"Packs de cash","de":"Bargeldpakete","it":"Pacchetti contanti","pt":"Pacotes de dinheiro","ru":"Пакеты наличных","ar":"حزم نقدية","zh":"现金包","ja":"現金パック","ko":"현금 팩","az":"Nağd paketləri","uk":"Пакети готівки","fa":"بسته‌های نقدی","hi":"नकद पैक"],
        "live_board":    ["tr":"Canlı liderlik","en":"Live leaderboard","es":"Clasificación en vivo","fr":"Classement live","de":"Live-Rangliste","it":"Classifica live","pt":"Ranking ao vivo","ru":"Живой рейтинг","ar":"الترتيب المباشر","zh":"实时排行","ja":"ライブ順位","ko":"실시간 순위","az":"Canlı reytinq","uk":"Живий рейтинг","fa":"جدول زنده","hi":"लाइव रैंकिंग"],
        "reset_game":    ["tr":"Oyunu sıfırla","en":"Reset game","es":"Reiniciar","fr":"Réinitialiser","de":"Spiel zurücksetzen","it":"Reset","pt":"Reiniciar","ru":"Сбросить игру","ar":"إعادة تعيين","zh":"重置游戏","ja":"リセット","ko":"게임 초기화","az":"Sıfırla","uk":"Скинути","fa":"بازنشانی","hi":"रीसेट"],
        "language":      ["tr":"Dil","en":"Language","es":"Idioma","fr":"Langue","de":"Sprache","it":"Lingua","pt":"Idioma","ru":"Язык","ar":"اللغة","zh":"语言","ja":"言語","ko":"언어","az":"Dil","uk":"Мова","fa":"زبان","hi":"भाषा"],
        "confirm":       ["tr":"Onayla","en":"Confirm","es":"Confirmar","fr":"Confirmer","de":"Bestätigen","it":"Conferma","pt":"Confirmar","ru":"Подтвердить","ar":"تأكيد","zh":"确认","ja":"確認","ko":"확인","az":"Təsdiqlə","uk":"Підтвердити","fa":"تأیید","hi":"पुष्टि"],
        "owned_msg":     ["tr":"Bu mülk senin","en":"You own this","es":"Es tuyo","fr":"Vous le possédez","de":"Gehört dir","it":"È tuo","pt":"É seu","ru":"Это ваше","ar":"هذا ملكك","zh":"已归你所有","ja":"所有済み","ko":"보유 중","az":"Sizindir","uk":"Це ваше","fa":"مال شماست","hi":"यह आपका है"],
        "low_funds":     ["tr":"Yetersiz bakiye","en":"Insufficient funds","es":"Fondos insuficientes","fr":"Fonds insuffisants","de":"Unzureichendes Guthaben","it":"Fondi insufficienti","pt":"Saldo insuficiente","ru":"Недостаточно средств","ar":"رصيد غير كافٍ","zh":"余额不足","ja":"残高不足","ko":"잔액 부족","az":"Balans kifayət etmir","uk":"Недостатньо коштів","fa":"موجودی ناکافی","hi":"अपर्याप्त शेष"],
        "price":         ["tr":"Fiyat","en":"Price","es":"Precio","fr":"Prix","de":"Preis","it":"Prezzo","pt":"Preço","ru":"Цена","ar":"السعر","zh":"价格","ja":"価格","ko":"가격","az":"Qiymət","uk":"Ціна","fa":"قیمت","hi":"मूल्य"],
        "income_day":    ["tr":"Gelir/gün","en":"Income/day","es":"Ingreso/día","fr":"Revenu/jour","de":"Einkommen/Tag","it":"Reddito/giorno","pt":"Renda/dia","ru":"Доход/день","ar":"دخل/يوم","zh":"收入/天","ja":"収入/日","ko":"수입/일","az":"Gəlir/gün","uk":"Дохід/день","fa":"درآمد/روز","hi":"आय/दिन"],
        "loading":       ["tr":"Yükleniyor…","en":"Loading…"],
        "list":          ["tr":"Liste","en":"List","es":"Lista","fr":"Liste","de":"Liste","it":"Lista","pt":"Lista","ru":"Список","ar":"قائمة","zh":"列表","ja":"リスト","ko":"목록","az":"Siyahı","uk":"Список","fa":"فهرست","hi":"सूची"],
        "owner":         ["tr":"Sahibi","en":"Owner","es":"Dueño","fr":"Propriétaire","de":"Eigentümer","it":"Proprietario","pt":"Dono","ru":"Владелец","ar":"المالك","zh":"业主","ja":"所有者","ko":"소유자","az":"Sahibi","uk":"Власник","fa":"مالک","hi":"मालिक"],
        "you":           ["tr":"Sen","en":"You","es":"Tú","fr":"Vous","de":"Du","it":"Tu","pt":"Você","ru":"Вы","ar":"أنت","zh":"你","ja":"あなた","ko":"나","az":"Sən","uk":"Ви","fa":"شما","hi":"आप"],
        "available":     ["tr":"Sahipsiz — satın alınabilir","en":"Unowned — available","es":"Disponible","fr":"Disponible","de":"Verfügbar","it":"Disponibile","pt":"Disponível","ru":"Свободно","ar":"متاح","zh":"可购买","ja":"購入可","ko":"구매 가능","az":"Boşdur","uk":"Вільно","fa":"در دسترس","hi":"उपलब्ध"],
        "send_offer":    ["tr":"Teklif Yolla","en":"Send Offer","es":"Enviar oferta","fr":"Faire une offre","de":"Angebot senden","it":"Invia offerta","pt":"Enviar oferta","ru":"Сделать предложение","ar":"إرسال عرض","zh":"出价","ja":"オファー","ko":"제안하기","az":"Təklif göndər","uk":"Запропонувати","fa":"پیشنهاد","hi":"प्रस्ताव भेजें"],
        "offer":         ["tr":"Teklif","en":"Offer","es":"Oferta","fr":"Offre","de":"Angebot","it":"Offerta","pt":"Oferta","ru":"Оферта","ar":"عرض","zh":"出价","ja":"オファー","ko":"제안","az":"Təklif","uk":"Оферта","fa":"پیشنهاد","hi":"प्रस्ताव"],
        "offer_accepted":["tr":"Teklif kabul edildi! Mülk senin.","en":"Offer accepted! It's yours."],
        "offer_rejected":["tr":"Teklif reddedildi — daha yüksek dene.","en":"Offer rejected — try higher."],
        "search_place":  ["tr":"Yer ara: şehir, ülke, semt…","en":"Search place: city, country…","es":"Buscar lugar…","fr":"Chercher un lieu…","de":"Ort suchen…","it":"Cerca luogo…","pt":"Buscar local…","ru":"Поиск места…","ar":"ابحث عن مكان…","zh":"搜索地点…","ja":"場所を検索…","ko":"장소 검색…","az":"Yer axtar…","uk":"Пошук місця…","fa":"جستجوی مکان…","hi":"स्थान खोजें…"],
        "vip_title":     ["tr":"VIP Üyelik","en":"VIP Membership"],
        "vip_active":    ["tr":"✓ Aktif","en":"✓ Active"],
        "vip_perk_income":   ["tr":"+%25 günlük gelir","en":"+25% daily income"],
        "vip_perk_badge":    ["tr":"VIP rozeti + altın tema","en":"VIP badge + gold theme"],
        "vip_perk_exclusive":["tr":"Özel & erken mülkler","en":"Exclusive & early properties"],
        "sub_disclosure":["tr":"Hooder VIP otomatik yenilenen bir aboneliktir. Ücret satın alma onayında Apple Kimliğine yansır; dönem bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir. Ayarlar → Apple Kimliği → Abonelikler'den istediğin zaman yönet/iptal et.","en":"Hooder VIP is an auto-renewable subscription. Payment is charged to your Apple ID at confirmation; it renews automatically unless canceled at least 24 hours before the period ends. Manage or cancel anytime in Settings → Apple ID → Subscriptions."],
        "privacy":["tr":"Gizlilik Politikası","en":"Privacy Policy","es":"Privacidad","fr":"Confidentialité","de":"Datenschutz","it":"Privacy","pt":"Privacidade","ru":"Конфиденциальность","ar":"الخصوصية","zh":"隐私政策","ja":"プライバシー","ko":"개인정보","az":"Məxfilik","uk":"Конфіденційність","fa":"حریم خصوصی","hi":"गोपनीयता"],
        "terms":["tr":"Kullanım Şartları","en":"Terms of Use","es":"Términos","fr":"Conditions","de":"Nutzungsbedingungen","it":"Termini","pt":"Termos","ru":"Условия","ar":"الشروط","zh":"使用条款","ja":"利用規約","ko":"이용약관","az":"İstifadə şərtləri","uk":"Умови","fa":"شرایط","hi":"शर्तें"],
    ]
}

// Global kısayol — View body içinde çağrılırsa dil değişimine tepki verir.
@MainActor func t(_ key: String) -> String { L10n.shared.t(key) }
