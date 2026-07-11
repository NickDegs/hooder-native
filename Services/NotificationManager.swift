import Foundation
import UserNotifications

// ── YEREL BİLDİRİM RETENTION MOTORU ───────────────────────────────────────────
// APNs/sunucu/imzalama entitlement'ı GEREKTİRMEZ (remote push CI otomatik-imzada
// desteklenmiyor — App Attest gibi). Bunun yerine cihazda zamanlanmış YEREL
// bildirimler ile terk eden oyuncuyu geri çağırır: uygulama arka plana geçince
// +1 gün / +3 gün / +7 gün "geri dön" bildirimleri kurulur; oyuncu geri açınca
// bekleyenler iptal edilir (yani AKTİF oyuncu asla rahatsız edilmez).
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    /// Onboarding sonunda bir kez izin ister. Reddederse sessizce geçer.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        UserDefaults.standard.set(true, forKey: "notify_asked")
        return granted
    }

    /// İzin verildiyse geri-çağırma bildirimlerini (yeniden) zamanla.
    /// Uygulama arka plana geçerken çağrılır.
    func scheduleRetention() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        center.removePendingNotificationRequests(withIdentifiers: Self.ids)

        // (id, gecikme-saati, başlık-anahtarı, gövde-anahtarı)
        let plan: [(String, Double, String, String)] = [
            (Self.ids[0], 24,  "notif_d1_title", "notif_d1_body"),
            (Self.ids[1], 72,  "notif_d3_title", "notif_d3_body"),
            (Self.ids[2], 168, "notif_d7_title", "notif_d7_body"),
        ]
        for (id, hours, tKey, bKey) in plan {
            let content = UNMutableNotificationContent()
            content.title = L10n.shared.t(tKey)
            content.body  = L10n.shared.t(bKey)
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(req)
        }
    }

    /// Oyuncu uygulamayı açtı → bekleyen geri-çağırmaları iptal et (aktif oyuncuyu rahatsız etme).
    func cancelRetention() {
        center.removePendingNotificationRequests(withIdentifiers: Self.ids)
        center.setBadgeCount(0)
    }

    private static let ids = ["retn_d1", "retn_d3", "retn_d7"]
}
