import Foundation
import Observation

struct WorkoutSet: Codable, Identifiable, Equatable {
    var id = UUID()
    var weight = ""
    var repetitions = ""
    var completed = false

    var isValid: Bool {
        let normalized = weight.replacingOccurrences(of: ",", with: ".")
        guard let kg = Double(normalized), kg.isFinite, kg >= 0,
              let reps = Int(repetitions), reps > 0 else { return false }
        return true
    }
}

struct PlanExercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var exerciseID: String
    var sets = [WorkoutSet(), WorkoutSet(), WorkoutSet()]
}

struct WorkoutPlan: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "新模板"
    var restSeconds = 90
    var exercises: [PlanExercise] = []
    var completedCount: Int { exercises.flatMap(\.sets).filter(\.completed).count }
}

struct WorkoutRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var plan: WorkoutPlan
    var durationSeconds: Int? = nil
}

struct ActiveWorkout: Codable, Identifiable {
    var id = UUID()
    var startedAt = Date()
    var plan: WorkoutPlan

    func elapsed(at date: Date = Date()) -> Int {
        max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

struct WorkoutArchive: Codable {
    var plans: [WorkoutPlan] = []
    var records: [WorkoutRecord] = []
    var activeWorkout: ActiveWorkout? = nil
}

@Observable final class WorkoutPlanStore {
    var archive: WorkoutArchive { didSet { save() } }
    var errorMessage: String?
    private let fileURL: URL
    private var canSave = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory.appending(path: "workout-plans.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                archive = try JSONDecoder().decode(WorkoutArchive.self, from: Data(contentsOf: self.fileURL))
            } else { archive = WorkoutArchive() }
        } catch {
            archive = WorkoutArchive()
            canSave = false
            errorMessage = "無法讀取健身計劃，原始資料已保留。請重新開啟 App 再試一次。"
        }
    }

    @discardableResult func addPlan() -> UUID {
        let plan = WorkoutPlan()
        archive.plans.append(plan)
        return plan.id
    }

    @discardableResult func saveTemplate(_ plan: WorkoutPlan) -> Bool {
        var updated = archive
        if let index = updated.plans.firstIndex(where: { $0.id == plan.id }) {
            updated.plans[index] = plan
        } else { updated.plans.append(plan) }
        return commit(updated)
    }

    @discardableResult func startWorkout(templateID: UUID, now: Date = Date()) -> Bool {
        guard archive.activeWorkout == nil,
              var plan = archive.plans.first(where: { $0.id == templateID }),
              !plan.exercises.isEmpty else { return false }
        for i in plan.exercises.indices {
            if plan.exercises[i].sets.isEmpty { plan.exercises[i].sets = [WorkoutSet()] }
            for j in plan.exercises[i].sets.indices {
                plan.exercises[i].sets[j].completed = false
                if plan.exercises[i].sets[j].weight.isEmpty { plan.exercises[i].sets[j].weight = "0" }
                if plan.exercises[i].sets[j].repetitions.isEmpty { plan.exercises[i].sets[j].repetitions = "10" }
            }
        }
        var updated = archive
        updated.activeWorkout = ActiveWorkout(startedAt: now, plan: plan)
        return commit(updated)
    }

    @discardableResult func finishWorkout(now: Date = Date()) -> Bool {
        guard let active = archive.activeWorkout, active.plan.completedCount > 0 else { return false }
        var updated = archive
        updated.records.insert(WorkoutRecord(date: now, plan: active.plan, durationSeconds: active.elapsed(at: now)), at: 0)
        updated.activeWorkout = nil
        return commit(updated)
    }

    @discardableResult func discardWorkout() -> Bool {
        var updated = archive
        updated.activeWorkout = nil
        return commit(updated)
    }

    // Critical transitions persist before changing the visible session state.
    private func commit(_ updated: WorkoutArchive) -> Bool {
        guard canSave else { return false }
        do {
            try write(updated)
            archive = updated
            return true
        } catch {
            errorMessage = "尚未儲存成功，請確認裝置儲存空間後重試。"
            return false
        }
    }

    private func write(_ value: WorkoutArchive) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: fileURL, options: .atomic)
    }

    private func save() {
        guard canSave else { return }
        do {
            try write(archive)
            errorMessage = nil
        } catch { errorMessage = "健身計劃尚未儲存成功，請確認裝置儲存空間。" }
    }
}
