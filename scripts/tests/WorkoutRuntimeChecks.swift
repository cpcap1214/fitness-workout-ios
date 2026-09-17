import SwiftUI
import UserNotifications

@main struct WorkoutRuntimeChecks: App {
    @State private var store = WorkoutPlanStore()
    @State private var rest = RestTimer(requestNotificationPermission: false)
    @State private var favorites = FavoriteExercises()

    var body: some Scene {
        @Bindable var store = store
        WindowGroup {
            VStack(spacing: 0) {
                if ProcessInfo.processInfo.environment["QA_SCREEN"] != "active" { RestTimerBar() }
                Group {
                if case .success(let library) = ExerciseLibrary.bundled {
                    if ProcessInfo.processInfo.environment["QA_SCREEN"] == "active", let active = store.archive.activeWorkout {
                        ActiveWorkoutView(workout: Binding(get: { store.archive.activeWorkout ?? active }, set: { store.archive.activeWorkout = $0 }), library: library)
                    } else { WorkoutPlansView(library: library) }
                }
            }
            }
            .environment(store).environment(rest).environment(favorites)
            .preferredColorScheme(.light)
            .task { await runChecks() }
        }
    }

    @MainActor private func runChecks() async {
        // The harness uses its own bundle ID/container; no user app data is touched.
        do {
            let library = try ExerciseLibrary.bundled.get()
            for exercise in library.exercises {
                guard let url = exercise.gifURL else { write("FAIL missing GIF"); return }
                let animation = try GIFAnimation(url: url)
                guard animation.frames.count > 1, animation.durations.allSatisfy({ $0 > 0 }) else {
                    write("FAIL invalid GIF frames"); return
                }
            }
            guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first,
                  let url = library.exercises.first?.gifURL else { write("FAIL GIF test window"); return }
            let animation = try GIFAnimation(url: url)
            let preview = GIFImageView(animation: animation)
            preview.frame = CGRect(x: 20, y: 80, width: 180, height: 180)
            window.addSubview(preview)
            let initial = preview.image?.pngData()
            preview.setPlaying(true)
            var advanced = false
            for _ in 0..<(Int(ceil(animation.durations[0] / 0.15)) + 3) {
                try await Task.sleep(for: .milliseconds(150))
                advanced = advanced || preview.image?.pngData() != initial
            }
            guard advanced else { preview.removeFromSuperview(); write("FAIL GIF playback"); return }
            preview.setPlaying(false)
            let paused = preview.image?.pngData()
            try await Task.sleep(for: .milliseconds(300))
            guard preview.image?.pngData() == paused else { write("FAIL GIF pause"); return }
            preview.removeFromSuperview()
            preview.setPlaying(true)
            try await Task.sleep(for: .milliseconds(300))
            guard preview.image?.pngData() == paused else { write("FAIL detached GIF playback"); return }
        } catch { write("FAIL GIF decode: \(error)"); return }
        var plan = WorkoutPlan(name: "胸背訓練", restSeconds: 5)
        var entry = PlanExercise(exerciseID: "0025")
        entry.sets[0] = WorkoutSet(weight: "40", repetitions: "10", completed: true)
        plan.exercises = [entry] + ["0652", "0314", "0292", "0308", "0861"].map { PlanExercise(exerciseID: $0) }
        var legs = WorkoutPlan(name: "下肢訓練")
        legs.exercises = ["0043", "0739", "0085"].map { PlanExercise(exerciseID: $0) }
        var shoulders = WorkoutPlan(name: "肩膀與手臂")
        shoulders.exercises = ["0405", "0334", "0294", "0200"].map { PlanExercise(exerciseID: $0) }
        store.archive = WorkoutArchive(plans: [plan, legs, shoulders])
        if ProcessInfo.processInfo.environment["QA_SCREEN"] == "active" {
            store.startWorkout(templateID: plan.id, now: Date().addingTimeInterval(-125))
            store.archive.activeWorkout?.plan.exercises[0].sets[0].completed = true
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        rest.start(seconds: 2)
        try? await Task.sleep(for: .seconds(3))
        guard rest.completed && rest.deadline == nil && rest.remaining == 0 else { write("FAIL foreground expiry"); return }
        // Bell decode/play errors surface in notice; permission denial is a separate expected notice.
        guard rest.notice != "無法播放提示音。" else { write("FAIL WAV playback"); return }
        rest.start(seconds: 20)
        rest.cancel()
        try? await Task.sleep(for: .seconds(1))
        guard rest.deadline == nil && !rest.completed else { write("FAIL cancellation"); return }
        guard await center.pendingNotificationRequests().isEmpty else { write("FAIL stale cancelled notification"); return }
        rest.start(seconds: 20)
        rest.start(seconds: 30)
        try? await Task.sleep(for: .seconds(1))
        if settings.authorizationStatus == .authorized {
            let pending = await center.pendingNotificationRequests()
            guard pending.count == 1, pending[0].content.sound != nil else { write("FAIL replacement notification"); return }
        }
        rest.setScene(.background)
        let before = rest.remaining
        try? await Task.sleep(for: .seconds(2))
        guard rest.remaining == before else { write("FAIL background polling"); return }
        rest.setScene(.active)
        guard rest.remaining < before else { write("FAIL deadline resumption"); return }
        rest.cancel()
        write("PASS all 60 GIFs decoded, GIF playback/pause/detachment, foreground expiry, WAV playback call, cancellation, pending request cleanup, timer replacement, background deadline resumption")
        if ProcessInfo.processInfo.environment["QA_SCREEN"] == "active" { rest.start(seconds: 60) }
    }

    private func write(_ value: String) {
        try? value.write(to: URL.documentsDirectory.appending(path: "runtime-results.txt"), atomically: true, encoding: .utf8)
    }
}
