import SwiftUI

struct WorkoutPlansView: View {
    let library: ExerciseLibrary
    @Environment(WorkoutPlanStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingTemplate: WorkoutPlan?
    @State private var showingWorkout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let active = store.archive.activeWorkout {
                        Button { showingWorkout = true } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("繼續運動").fontWeight(.bold)
                                Spacer()
                                WorkoutClock(startedAt: active.startedAt, compact: true)
                            }
                            .padding(20).foregroundStyle(.white)
                            .background(.black, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .accessibilityIdentifier("resume-workout")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                        ForEach(Array(store.archive.plans.enumerated()), id: \.element.id) { index, plan in
                            NavigationLink {
                                TemplateOverview(templateID: plan.id, library: library, begin: { showingWorkout = true })
                            } label: { TemplateCard(plan: plan, library: library, colorIndex: index) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("template-\(plan.id)")
                        }
                        Button { editingTemplate = WorkoutPlan() } label: {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemGray6))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus").font(.system(size: 30, weight: .light))
                                        Text("建立模板").font(.headline)
                                    }.foregroundStyle(.primary)
                                }
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("create-template")
                    }
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                }
                .padding(20)
            }
            .background(.white)
            .navigationTitle("健身計劃")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { WorkoutHistoryView(library: library) } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }.accessibilityLabel("訓練紀錄")
                }
            }
            .sheet(item: $editingTemplate) { template in TemplateEditor(initial: template, library: library) }
            .fullScreenCover(isPresented: $showingWorkout) {
                if let active = store.archive.activeWorkout {
                    ActiveWorkoutView(workout: Binding(
                        get: { store.archive.activeWorkout ?? active },
                        set: { if store.archive.activeWorkout?.id == active.id { store.archive.activeWorkout = $0 } }
                    ), library: library)
                }
            }
            .onChange(of: store.archive.activeWorkout?.id) { _, id in if id == nil { showingWorkout = false } }
        }
    }
}

struct TemplateCard: View {
    let plan: WorkoutPlan
    let library: ExerciseLibrary
    let colorIndex: Int
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight: CGFloat = 23
    @ScaledMetric(relativeTo: .headline) private var titleHeight: CGFloat = 24
    private let colors: [Color] = [
        Color(red: 0.88, green: 0.92, blue: 1),
        Color(red: 0.89, green: 0.94, blue: 0.88),
        Color(red: 1, green: 0.91, blue: 0.85),
        Color(red: 0.94, green: 0.89, blue: 0.98)
    ]
    private var names: [String] {
        plan.exercises.compactMap { item in library.exercises.first(where: { $0.id == item.exerciseID })?.name }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(colors[colorIndex % colors.count])
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geometry in
                    // The fixed square never grows; large text shows fewer exercise lines.
                    let available = max(0, geometry.size.height - 48 - titleHeight)
                    let capacity = max(1, min(4, Int(available / lineHeight)))
                    let shown = names.count > capacity ? max(0, capacity - 1) : capacity
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 5) {
                            Text(plan.name.isEmpty ? "未命名模板" : plan.name)
                                .font(.headline).lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(names.prefix(shown).enumerated()), id: \.offset) { _, name in
                                Text(name).font(.subheadline).lineLimit(1).truncationMode(.tail)
                            }
                            if names.count > shown { Text("…").font(.subheadline.weight(.semibold)) }
                        }
                        .foregroundStyle(.black.opacity(0.65))
                    }
                    .padding(18)
                }
            }
            .foregroundStyle(.black)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(([plan.name] + names).joined(separator: "，"))
    }
}

struct TemplateOverview: View {
    let templateID: UUID
    let library: ExerciseLibrary
    let begin: () -> Void
    @Environment(WorkoutPlanStore.self) private var store
    @Environment(RestTimer.self) private var rest
    @Environment(\.dismiss) private var dismiss
    @State private var editing: WorkoutPlan?
    @State private var deleting = false

    private var template: WorkoutPlan? { store.archive.plans.first { $0.id == templateID } }
    var body: some View {
        Group {
            if let template {
                List {
                    Section {
                        ForEach(template.exercises) { item in
                            HStack {
                                Text(library.exercises.first(where: { $0.id == item.exerciseID })?.name ?? "動作")
                                Spacer()
                                Text("\(item.sets.count) 組").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section { LabeledContent("組間休息", value: "\(template.restSeconds) 秒") }
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                }
                .scrollContentBackground(.hidden).background(.white)
                .navigationTitle(template.name)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Button {
                        if store.archive.activeWorkout != nil { begin() }
                        else if store.startWorkout(templateID: templateID) { rest.cancel(); begin() }
                    } label: {
                        Label(store.archive.activeWorkout == nil ? "開始運動" : "繼續運動", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .background(.black, in: RoundedRectangle(cornerRadius: 20))
                    .disabled(template.exercises.isEmpty && store.archive.activeWorkout == nil)
                    .opacity(template.exercises.isEmpty && store.archive.activeWorkout == nil ? 0.4 : 1)
                    .padding(20).background(.white)
                    .accessibilityIdentifier("start-workout")
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("編輯模板", systemImage: "pencil") { editing = template }
                            Button("刪除模板", systemImage: "trash", role: .destructive) { deleting = true }
                        } label: { Image(systemName: "ellipsis") }.accessibilityLabel("模板選項")
                    }
                }
            }
        }
        .sheet(item: $editing) { TemplateEditor(initial: $0, library: library) }
        .confirmationDialog("刪除此模板？", isPresented: $deleting, titleVisibility: .visible) {
            Button("刪除模板", role: .destructive) {
                store.archive.plans.removeAll { $0.id == templateID }
                dismiss()
            }
            Button("取消", role: .cancel) { }
        }
    }
}

struct TemplateEditor: View {
    @State private var draft: WorkoutPlan
    let library: ExerciseLibrary
    @Environment(WorkoutPlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selecting = false
    @State private var editMode: EditMode = .inactive

    init(initial: WorkoutPlan, library: ExerciseLibrary) {
        _draft = State(initialValue: initial)
        self.library = library
    }

    var body: some View {
        NavigationStack {
            List {
                Section("模板名稱") { TextField("模板名稱", text: $draft.name).accessibilityIdentifier("template-name") }
                Section("動作") {
                    ForEach($draft.exercises) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(library.exercises.first(where: { $0.id == item.exerciseID })?.name ?? "動作").fontWeight(.semibold)
                            Stepper("\(item.sets.count) 組", value: Binding(get: { item.sets.count }, set: { count in
                                if count > item.sets.count {
                                    item.sets.append(WorkoutSet(weight: "0", repetitions: "10"))
                                } else { item.sets = Array(item.sets.prefix(count)) }
                            }), in: 1...20)
                        }.padding(.vertical, 4)
                    }
                    .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { draft.exercises.remove(atOffsets: $0) }
                    Button("加入動作", systemImage: "plus") { selecting = true }
                }
                Section("組間休息") { Stepper("\(draft.restSeconds) 秒", value: $draft.restSeconds, in: 5...600, step: 5) }
                if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .scrollContentBackground(.hidden).background(.white)
            .environment(\.editMode, $editMode)
            .navigationTitle("編輯模板").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.saveTemplate(draft) { dismiss() }
                    }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.exercises.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(editMode.isEditing ? "完成排序" : "調整順序") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                }
            }
            .sheet(isPresented: $selecting) {
                ExercisePicker(library: library) { ids in
                    draft.exercises.append(contentsOf: ids.map {
                        PlanExercise(exerciseID: $0, sets: (0..<3).map { _ in WorkoutSet(weight: "0", repetitions: "10") })
                    })
                }
            }
        }
    }
}

struct WorkoutClock: View {
    let startedAt: Date
    var compact = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
            Text(Self.format(seconds))
                .font(.system(size: compact ? 18 : 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("運動時間 \(seconds / 60) 分 \(seconds % 60) 秒")
        }
    }
    static func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

struct ActiveWorkoutView: View {
    @Binding var workout: ActiveWorkout
    let library: ExerciseLibrary
    @Environment(WorkoutPlanStore.self) private var store
    @Environment(RestTimer.self) private var rest
    @Environment(\.dismiss) private var dismiss
    @State private var finishing = false
    @State private var discarding = false
    @FocusState private var editing: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RestTimerBar()
                HStack(alignment: .center) {
                    WorkoutClock(startedAt: workout.startedAt)
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Spacer()
                    Text("\(workout.plan.completedCount) / \(workout.plan.exercises.flatMap(\.sets).count) 組")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                List {
                    ForEach($workout.plan.exercises) { $item in
                        Section {
                            HStack {
                                Text("組").frame(width: 28)
                                Text("kg").frame(maxWidth: .infinity)
                                Text("次數").frame(maxWidth: .infinity)
                                Text("完成").frame(width: 44)
                            }.font(.caption).foregroundStyle(.secondary)
                            ForEach($item.sets) { $set in
                                HStack(spacing: 10) {
                                    Text("\((item.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)")
                                        .font(.subheadline.monospacedDigit()).frame(width: 28)
                                    TextField("0", text: $set.weight)
                                        .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("重量，公斤").disabled(set.completed)
                                        .focused($editing, equals: "weight-\(set.id)")
                                    TextField("10", text: $set.repetitions)
                                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("次數").disabled(set.completed)
                                        .focused($editing, equals: "reps-\(set.id)")
                                    Button {
                                        editing = nil
                                        if set.completed { set.completed = false }
                                        else { set.completed = true; rest.start(seconds: workout.plan.restSeconds) }
                                    } label: {
                                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 27, weight: .medium))
                                            .foregroundStyle(set.completed ? Color.green : Color.secondary)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!set.completed && !set.isValid)
                                    .accessibilityLabel(set.completed ? "取消完成這一組" : "完成這一組並休息")
                                }
                            }
                            .onDelete { item.sets.remove(atOffsets: $0) }
                            Button("新增一組", systemImage: "plus") {
                                let last = item.sets.last
                                item.sets.append(WorkoutSet(weight: last?.weight ?? "0", repetitions: last?.repetitions ?? "10"))
                            }.font(.subheadline)
                        } header: {
                            HStack {
                                Text(library.exercises.first(where: { $0.id == item.exerciseID })?.name ?? "動作")
                                    .font(.headline).foregroundStyle(.primary).textCase(nil)
                                Spacer()
                                if let exercise = library.exercises.first(where: { $0.id == item.exerciseID }) {
                                    NavigationLink { ExerciseDetail(exercise: exercise) } label: { Image(systemName: "play.rectangle") }
                                        .accessibilityLabel("\(exercise.name)動作教學")
                                }
                            }
                        }
                    }
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                    Section {
                        Button("結束運動", systemImage: "checkmark.flag") { editing = nil; finishing = true }
                            .disabled(workout.plan.completedCount == 0)
                        Button("放棄本次運動", role: .destructive) { discarding = true }
                    }
                }
                .scrollContentBackground(.hidden).background(.white)
            }
            .navigationTitle(workout.plan.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("收合") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成輸入") { editing = nil } }
            }
            .confirmationDialog("結束並儲存本次運動？", isPresented: $finishing, titleVisibility: .visible) {
                Button("儲存紀錄") { if store.finishWorkout() { rest.cancel(); dismiss() } }
                Button("繼續運動", role: .cancel) { }
            }
            .confirmationDialog("放棄本次運動？", isPresented: $discarding, titleVisibility: .visible) {
                Button("放棄本次運動", role: .destructive) { if store.discardWorkout() { rest.cancel(); dismiss() } }
                Button("繼續運動", role: .cancel) { }
            }
        }
    }
}

struct WorkoutHistoryView: View {
    let library: ExerciseLibrary
    @Environment(WorkoutPlanStore.self) private var store
    var body: some View {
        List {
            if store.archive.records.isEmpty { Text("尚無訓練紀錄").foregroundStyle(.secondary) }
            ForEach(store.archive.records) { record in
                NavigationLink { WorkoutRecordView(record: record, library: library) } label: {
                    HStack {
                        Text(record.plan.name)
                        Spacer()
                        Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(.white)
        .navigationTitle("訓練紀錄")
    }
}

struct WorkoutRecordView: View {
    let record: WorkoutRecord
    let library: ExerciseLibrary
    var body: some View {
        List {
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
            if let duration = record.durationSeconds { LabeledContent("運動時間", value: WorkoutClock.format(duration)) }
            ForEach(record.plan.exercises) { item in
                if item.sets.contains(where: \.completed) {
                    Section(library.exercises.first(where: { $0.id == item.exerciseID })?.name ?? "動作") {
                        ForEach(Array(item.sets.enumerated()), id: \.element.id) { index, set in
                            if set.completed {
                                HStack { Text("第 \(index + 1) 組"); Spacer(); Text("\(set.weight) kg × \(set.repetitions) 次") }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(.white)
        .navigationTitle(record.plan.name).navigationBarTitleDisplayMode(.inline)
    }
}
private struct ExercisePicker: View {
    let library: ExerciseLibrary
    let onAdd: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String] = []
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExerciseLibrary.categories, id: \.self) { category in
                    let exercises = library.exercises.filter {
                        $0.category == category && (search.isEmpty || $0.name.localizedStandardContains(search))
                    }
                    if !exercises.isEmpty {
                        Section(category) {
                            ForEach(exercises) { exercise in
                                Button {
                                    if selected.contains(exercise.id) { selected.removeAll { $0 == exercise.id } }
                                    else { selected.append(exercise.id) }
                                } label: {
                                    HStack {
                                        Text(exercise.name).foregroundStyle(.primary)
                                        Spacer()
                                        if let index = selected.firstIndex(of: exercise.id) {
                                            Text("\(index + 1)")
                                                .font(.caption.bold()).foregroundStyle(.white)
                                                .frame(width: 26, height: 26).background(.black, in: Circle())
                                        } else { Image(systemName: "circle").foregroundStyle(.secondary) }
                                    }
                                }
                                .accessibilityAddTraits(selected.contains(exercise.id) ? .isSelected : [])
                                .accessibilityIdentifier("select-exercise-\(exercise.id)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("選擇動作")
            .searchable(text: $search, prompt: "搜尋動作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入（\(selected.count)）") { onAdd(selected); dismiss() }
                        .disabled(selected.isEmpty).accessibilityIdentifier("confirm-exercise-selection")
                }
            }
        }
    }
}

struct RestTimerBar: View {
    @Environment(RestTimer.self) private var rest
    var body: some View {
        if rest.deadline != nil || rest.completed {
            VStack(spacing: 8) {
                HStack {
                    Label(rest.completed ? "休息結束" : "組間休息", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if rest.deadline != nil {
                        Text(String(format: "%02d:%02d", rest.remaining / 60, rest.remaining % 60))
                            .font(.title3.monospacedDigit().bold())
                            .accessibilityLabel("剩餘 \(rest.remaining) 秒")
                    }
                    Button(rest.completed ? "關閉" : "略過") { rest.cancel() }
                        .buttonStyle(.bordered)
                }
                if let notice = rest.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
