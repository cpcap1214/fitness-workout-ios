import SwiftUI
import AVFoundation
import UserNotifications
import Observation

@Observable final class RestTimer: NSObject, AVAudioPlayerDelegate, UNUserNotificationCenterDelegate {
    private(set) var deadline: Date?
    private(set) var remaining = 0
    private(set) var completed = false
    var notice: String?
    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private var requestID: String?
    private var foreground = true
    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()
    private let requestNotificationPermission: Bool
    static let soundFile = "350548__fairhavencollection__bell-hit.wav"

    init(requestNotificationPermission: Bool = true) {
        self.requestNotificationPermission = requestNotificationPermission
        super.init()
        center.delegate = self
        requestID = defaults.string(forKey: "workout.rest.request")
        if let saved = defaults.object(forKey: "workout.rest.deadline") as? Date {
            deadline = saved
            update(playSound: false)
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.foreground else { return }
                self.update(playSound: true)
            }
        }
    }

    func start(seconds: Int) {
        cancel()
        completed = false
        notice = nil
        let duration = max(1, seconds)
        let id = UUID().uuidString
        requestID = id
        // 保存結束時間，回到前景或重開 App 時可重新算出剩餘秒數。
        deadline = Date().addingTimeInterval(Double(duration))
        remaining = duration
        defaults.set(deadline, forKey: "workout.rest.deadline")
        defaults.set(id, forKey: "workout.rest.request")
        Task { await scheduleNotification(id: id) }
    }

    private func scheduleNotification(id: String) async {
        do {
            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined && requestNotificationPermission {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
                settings = await center.notificationSettings()
            }
            guard requestID == id, let deadline else { return }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                notice = "通知未開啟，請保持 App 在前景以聽到休息提示音。"
                return
            }
            if settings.soundSetting != .enabled { notice = "通知聲音未開啟，背景提醒可能不會發出聲音。" }
            let interval = deadline.timeIntervalSinceNow
            guard interval > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "組間休息結束"
            content.body = "準備開始下一組。"
            content.sound = UNNotificationSound(named: UNNotificationSoundName(Self.soundFile))
            let request = UNNotificationRequest(identifier: id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false))
            try await center.add(request)
            if requestID != id { center.removePendingNotificationRequests(withIdentifiers: [id]) }
        } catch { notice = "無法設定背景提醒，請保持 App 在前景。" }
    }

    func setScene(_ phase: ScenePhase) {
        if phase == .active {
            // A background notification owns the sound when its deadline passed while away.
            if !foreground { update(playSound: false) }
            foreground = true
        } else if phase == .background { foreground = false }
    }

    func cancel() {
        if let requestID {
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
            center.removeDeliveredNotifications(withIdentifiers: [requestID])
        }
        requestID = nil
        deadline = nil
        remaining = 0
        completed = false
        defaults.removeObject(forKey: "workout.rest.deadline")
        defaults.removeObject(forKey: "workout.rest.request")
    }

    private func update(playSound: Bool) {
        guard let deadline else { return }
        remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if remaining == 0 {
            cancel()
            completed = true
            if playSound { playBell() }
        }
    }

    func playBell() {
        do {
            guard let url = Bundle.main.url(forResource: Self.soundFile, withExtension: nil) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            guard player?.play() == true else { throw CocoaError(.fileReadUnknown) }
        } catch { notice = "無法播放提示音。"; releaseAudio() }
    }

    private func releaseAudio() {
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.releaseAudio() }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Foreground countdown plays the WAV itself; suppress duplicate notification audio.
        completionHandler([])
    }
}
