import Foundation

@main struct WorkoutPlanChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "plans.json")
        let store = WorkoutPlanStore(fileURL: file)
        precondition(store.archive.plans.count == 5)
        precondition(store.archive.presetVersion == 2)
        precondition(WorkoutPlanStore(fileURL: file).archive.plans.count == 5, "Seed only once")
        precondition(store.archive.plans.allSatisfy { $0.presetID != nil })
        var renamed = store.archive.plans[0]
        renamed.name = "重新命名"
        precondition(store.saveTemplate(renamed))
        precondition(WorkoutPlanStore(fileURL: file).archive.plans[0].presetID == renamed.presetID)
        store.archive.plans.removeAll()
        precondition(WorkoutPlanStore(fileURL: file).archive.plans.isEmpty, "Do not restore deleted presets")
        var template = WorkoutPlan(name: "胸背模板")
        template.exercises = [PlanExercise(exerciseID: "0025"), PlanExercise(exerciseID: "0652")]
        template.exercises.swapAt(0, 1)
        template.exercises[0].sets[0] = WorkoutSet(weight: "12.5", repetitions: "8", completed: true)
        precondition(store.saveTemplate(template))
        let reopened = WorkoutPlanStore(fileURL: file)
        precondition(reopened.archive.plans[0].exercises.map(\.exerciseID) == ["0652", "0025"])
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        precondition(reopened.startWorkout(templateID: template.id, now: start))
        precondition(reopened.archive.activeWorkout?.plan.completedCount == 0)
        precondition(!reopened.startWorkout(templateID: template.id), "Never overwrite an active workout")
        precondition(reopened.archive.activeWorkout?.elapsed(at: start.addingTimeInterval(125)) == 125)
        reopened.archive.activeWorkout?.plan.exercises[0].sets[0] = WorkoutSet(weight: "20", repetitions: "10", completed: true)
        let restored = WorkoutPlanStore(fileURL: file)
        precondition(restored.archive.activeWorkout?.startedAt == start)
        precondition(restored.archive.activeWorkout?.plan.completedCount == 1)
        precondition(restored.archive.plans[0].exercises[0].sets[0].weight == "12.5", "Session must not mutate template")
        restored.archive.plans[0].name = "修改後的模板"
        precondition(restored.archive.activeWorkout?.plan.name == "胸背模板")
        precondition(restored.finishWorkout(now: start.addingTimeInterval(185)))
        precondition(restored.archive.records[0].durationSeconds == 185)
        precondition(restored.archive.records[0].plan.exercises[0].sets[0].weight == "20")
        precondition(restored.archive.activeWorkout == nil)
        precondition(!restored.finishWorkout(), "No duplicate records")
        precondition(restored.startWorkout(templateID: template.id))
        precondition(restored.archive.activeWorkout?.plan.completedCount == 0)
        precondition(restored.finishWorkout(), "An unchecked workout can still end")
        precondition(restored.archive.records.first?.plan.completedCount == 0)
        precondition(restored.archive.activeWorkout == nil)
        restored.archive.records.removeFirst()
        precondition(restored.startWorkout(templateID: template.id))
        precondition(restored.discardWorkout())
        precondition(restored.archive.records.count == 1)
        restored.archive.plans.removeAll()
        precondition(WorkoutPlanStore(fileURL: file).archive.records.count == 1)
        precondition(WorkoutSet(weight: "0", repetitions: "10").isValid)
        precondition(WorkoutSet(weight: "2,5", repetitions: "10").isValid)
        for pair in [("", "10"), ("-1", "10"), ("nan", "10"), ("inf", "10"), ("10", "0"), ("10", "1.5")] {
            precondition(!WorkoutSet(weight: pair.0, repetitions: pair.1).isValid)
        }
        // Earlier archives do not contain an active workout or duration field.
        let encoded = try JSONEncoder().encode(restored.archive)
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacy.removeValue(forKey: "activeWorkout")
        var records = legacy["records"] as! [[String: Any]]
        records[0].removeValue(forKey: "durationSeconds")
        legacy["records"] = records
        let decoded = try JSONDecoder().decode(WorkoutArchive.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(decoded.records.count == 1 && decoded.records[0].durationSeconds == nil)
        legacy.removeValue(forKey: "presetVersion")
        legacy["plans"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([template]))
        let migrationFile = directory.appending(path: "legacy.json")
        try JSONSerialization.data(withJSONObject: legacy).write(to: migrationFile)
        let migrated = WorkoutPlanStore(fileURL: migrationFile)
        precondition(migrated.archive.plans.count == 6 && migrated.archive.plans[0].id == template.id)
        precondition(migrated.archive.records.count == 1)
        precondition(WorkoutPlanStore(fileURL: migrationFile).archive.plans.count == 6)
        let v1File = directory.appending(path: "v1.json")
        var oldPresets = WorkoutPlanStore.presetTemplates
        for index in oldPresets.indices { oldPresets[index].presetID = nil }
        let v1 = WorkoutArchive(plans: [template] + oldPresets, presetVersion: 1)
        try JSONEncoder().encode(v1).write(to: v1File)
        let upgraded = WorkoutPlanStore(fileURL: v1File)
        precondition(upgraded.archive.plans.count == 6)
        precondition(upgraded.archive.plans[0].presetID == nil)
        precondition(upgraded.archive.plans.dropFirst().allSatisfy { $0.presetID != nil })
        precondition(upgraded.archive.plans.map(\.id) == v1.plans.map(\.id))
        let corrupt = directory.appending(path: "corrupt.json")
        let original = Data("not json".utf8)
        try original.write(to: corrupt)
        let brokenStore = WorkoutPlanStore(fileURL: corrupt)
        precondition(!brokenStore.saveTemplate(template))
        let preserved = try Data(contentsOf: corrupt)
        precondition(preserved == original)
        print("PASS: template persistence/order, separate repeatable sessions, elapsed time, resume, immutable history, discard, legacy migration, validation, corrupt-file protection")
    }
}
