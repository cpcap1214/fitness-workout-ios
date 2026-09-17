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
    var presetID: String? = nil
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
    var presetVersion: Int? = nil
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
        installPresetsIfNeeded()
    }

    private func installPresetsIfNeeded() {
        guard canSave, (archive.presetVersion ?? 0) < 2 else { return }
        var updated = archive
        if archive.presetVersion == nil {
            updated.plans.append(contentsOf: Self.presetTemplates)
        } else {
            // Version 1 did not persist template origin. Match the shipped names and
            // exercise order once; subsequent edits retain the explicit preset ID.
            for preset in Self.presetTemplates {
                if let index = updated.plans.firstIndex(where: {
                    $0.presetID == nil && $0.name == preset.name &&
                    $0.exercises.map(\.exerciseID) == preset.exercises.map(\.exerciseID)
                }) {
                    updated.plans[index].presetID = preset.presetID
                }
            }
        }
        updated.presetVersion = 2
        _ = commit(updated)
    }

    static var presetTemplates: [WorkoutPlan] {
        let definitions: [(String, [String])] = [
            ("雙分化・上半身", ["0025", "0198", "0861", "0405", "0294", "0200"]),
            ("雙分化・下半身", ["0043", "0085", "0739", "0586", "0274"]),
            ("三分化・推", ["0025", "0314", "0405", "0334", "0200"]),
            ("三分化・拉", ["0198", "0027", "0861", "0380", "0313"]),
            ("三分化・腿", ["0043", "0085", "3470", "0586", "0276"])
        ]
        return definitions.map { name, ids in
            WorkoutPlan(presetID: name, name: name, exercises: ids.map {
                PlanExercise(exerciseID: $0, sets: (0..<3).map { _ in WorkoutSet(weight: "0", repetitions: "10") })
            })
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
        guard let active = archive.activeWorkout else { return false }
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
