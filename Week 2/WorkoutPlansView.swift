import SwiftUI

struct WorkoutPlansView: View {
    let library: ExerciseLibrary
    var onOpenWorkout: () -> Void = {}
    var navigationPath: Binding<[UUID]>? = nil
    @State private var localPath: [UUID] = []
    @Environment(WorkoutPlanStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingTemplate: WorkoutPlan?

    var body: some View {
        NavigationStack(path: navigationPath ?? $localPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    templateSection("我的模板", plans: store.archive.plans.filter { $0.presetID == nil }, allowsCreation: true)
                    Divider().padding(.vertical, 4)
                    templateSection("預設模板", plans: store.archive.plans.filter { $0.presetID != nil }, allowsCreation: false)
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                }
                .padding(20)
            }
            .background(.white)
            .navigationTitle("健身計劃")
            .navigationDestination(for: UUID.self) { id in
                TemplateOverview(templateID: id, library: library, begin: onOpenWorkout)
            }
            .sheet(item: $editingTemplate) { template in TemplateEditor(initial: template, library: library) }

        }
    }
    private func templateSection(_ title: String, plans: [WorkoutPlan], allowsCreation: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink(value: plan.id) {
                        TemplateCard(plan: plan, library: library, colorIndex: index)
                    }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("template-\(plan.id)")
                }
                if allowsCreation {
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
            }
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
                            let exercise = library.exercises.first { $0.id == item.exerciseID }
                            HStack(spacing: 14) {
                                if let exercise {
                                    ExerciseThumbnail(exercise: exercise)
                                        .frame(width: 76, height: 76)
                                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                Text(exercise?.name ?? "動作")
                                    .font(.body.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Text("\(item.sets.count) 組")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .padding(14)
                            .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: AppDesign.cardRadius))
                            .accessibilityElement(children: .combine)
                            .editorRow()
                        }
                    }
                    Section {
                        LabeledContent("組間休息", value: "\(template.restSeconds) 秒")
                            .font(.subheadline).appCard().editorRow()
                    }
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
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(template.exercises.isEmpty && store.archive.activeWorkout == nil)
                    .opacity(template.exercises.isEmpty && store.archive.activeWorkout == nil ? 0.4 : 1)
                    .actionBar()
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selecting = false
    @State private var editMode: EditMode = .inactive
    @FocusState private var editingName: Bool

    init(initial: WorkoutPlan, library: ExerciseLibrary) {
        _draft = State(initialValue: initial)
        self.library = library
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("輸入模板名稱", text: $draft.name)
                        .font(.title3.weight(.semibold))
                        .focused($editingName)
                        .submitLabel(.done)
                        .padding(20)
                        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: AppDesign.cardRadius))
                        .accessibilityIdentifier("template-name")
                        .editorRow()
                } header: { sectionTitle("模板名稱") }
                Section {
                    VStack(spacing: 18) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.title2).foregroundStyle(AppDesign.accent)
                                .frame(width: 44, height: 44)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            Text("\(draft.restSeconds) 秒")
                                .font(.title3.weight(.semibold)).monospacedDigit()
                            Spacer(minLength: 4)
                            Stepper("休息秒數", value: $draft.restSeconds, in: 5...600, step: 5)
                                .labelsHidden()
                                .accessibilityValue("\(draft.restSeconds) 秒")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 8) {
                            ForEach([30, 60, 90, 120], id: \.self) { seconds in
                                Button { draft.restSeconds = seconds } label: {
                                    Text("\(seconds) 秒").font(.subheadline.weight(.medium)).lineLimit(1)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .foregroundStyle(draft.restSeconds == seconds ? Color.white : Color.primary)
                                        .background(draft.restSeconds == seconds ? Color.black : Color.white, in: Capsule())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityAddTraits(draft.restSeconds == seconds ? .isSelected : [])
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.92, green: 0.95, blue: 1), in: RoundedRectangle(cornerRadius: 22))
                    .editorRow()
                } header: { sectionTitle("組間休息") }
                Section {
                    ForEach($draft.exercises) { $item in
                        exerciseCard(item: $item)
                            .editorRow()
                    }
                    .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { draft.exercises.remove(atOffsets: $0) }
                    Button { editingName = false; selecting = true } label: {
                        Label("加入動作", systemImage: "plus")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.primary)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("add-template-exercises")
                    .editorRow()
                } header: { sectionTitle("動作順序") }
                if let error = store.errorMessage { Text(error).foregroundStyle(.red).editorRow() }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(.white)
            .environment(\.editMode, $editMode)
            .navigationTitle("編輯模板").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    editingName = false
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.saveTemplate(draft) { dismiss() }
                } label: {
                    Label("儲存模板", systemImage: "checkmark")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!canSave)
                .accessibilityIdentifier("save-template")
                .actionBar()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("取消編輯模板")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editMode.isEditing ? "完成" : "排序") {
                        editingName = false
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }.disabled(draft.exercises.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成輸入") { editingName = false } }
            }
            .sheet(isPresented: $selecting) {
                ExercisePicker(library: library) { ids in
                    draft.exercises.append(contentsOf: ids.map {
                        PlanExercise(exerciseID: $0, sets: (0..<3).map { _ in WorkoutSet(weight: "0", repetitions: "10") })
                    })
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(Color.black).textCase(nil)
            .padding(.top, 12).padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func exerciseCard(item: Binding<PlanExercise>) -> some View {
        let exercise = library.exercises.first { $0.id == item.wrappedValue.exerciseID }
        let number = (draft.exercises.firstIndex { $0.id == item.wrappedValue.id } ?? 0) + 1
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                if let exercise {
                    ExerciseThumbnail(exercise: exercise)
                        .frame(width: 64, height: 64)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Text(exercise?.name ?? "動作")
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(String(format: "%02d", number))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("組數").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Stepper(value: Binding(get: { item.wrappedValue.sets.count }, set: { count in
                    if count > item.wrappedValue.sets.count {
                        item.wrappedValue.sets.append(WorkoutSet(weight: "0", repetitions: "10"))
                    } else { item.wrappedValue.sets = Array(item.wrappedValue.sets.prefix(count)) }
                }), in: 1...20) {
                    Text("\(item.wrappedValue.sets.count) 組").font(.body.weight(.semibold)).monospacedDigit()
                }
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("\(exercise?.name ?? "動作")組數")
            }
        }
        .padding(16)
        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: AppDesign.cardRadius))
    }
}

private extension View {
    func editorRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.white)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

struct WorkoutClock: View {
    let startedAt: Date
    var compact = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            // 以開始時間計算累計秒數，收合或切換分頁後不依賴畫面持續累加。
            let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
            Text(Self.format(seconds))
                .font(AppDesign.timerFont(compact: compact))
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
    var onFinished: () -> Void = {}
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
                            if let exercise = library.exercises.first(where: { $0.id == item.exerciseID }) {
                                NavigationLink { ExerciseDetail(exercise: exercise) } label: {
                                    HStack(spacing: 14) {
                                        ExerciseThumbnail(exercise: exercise)
                                            .frame(width: 64, height: 64)
                                            .background(.white, in: RoundedRectangle(cornerRadius: AppDesign.imageRadius))
                                        Text(exercise.name).font(.headline).foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }.padding(.vertical, 6)
                                }.accessibilityLabel("\(exercise.name)動作教學")
                            }

                            HStack {
                                Text("組").frame(width: 28)
                                Text("kg").frame(maxWidth: .infinity)
                                Text("次數").frame(maxWidth: .infinity)
                                Image(systemName: "checkmark").frame(width: 44).accessibilityLabel("完成")
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
                                        // 完成一組就開始休息；取消勾選時，也取消目前的休息倒數。
                                        if set.completed { set.completed = false; rest.cancel() }
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
                        }
                        .listRowBackground(AppDesign.surface)
                    }
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                    Section {
                        Button("放棄本次運動", role: .destructive) { discarding = true }
                    }
                }
                .scrollContentBackground(.hidden).background(.white)
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                Button { editing = nil; finishing = true } label: {
                    Label("結束運動", systemImage: "checkmark.flag")
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("finish-workout")
                .actionBar()
            }
            .navigationTitle(workout.plan.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("收合") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成輸入") { editing = nil } }
            }
            .alert("無法儲存", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("好", role: .cancel) { }
            } message: { Text(store.errorMessage ?? "請再試一次。") }
            .confirmationDialog(workout.plan.completedCount == 0 ? "尚未勾選任何組數，要儲存為 0 組紀錄嗎？" : "結束並儲存已完成的 \(workout.plan.completedCount) 組？", isPresented: $finishing, titleVisibility: .visible) {
                Button("儲存紀錄") { if store.finishWorkout() { rest.cancel(); onFinished(); dismiss() } }
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
        ScrollView {
            LazyVStack(spacing: 14) {
                if store.archive.records.isEmpty {
                    ContentUnavailableView("尚無運動紀錄", systemImage: "clock.arrow.circlepath")
                        .padding(.top, 60)
                }
                ForEach(store.archive.records) { record in
                    NavigationLink { WorkoutRecordView(record: record, library: library) } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(record.plan.name).font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            Divider()
                            LabeledContent("日期", value: AppDesign.date(record.date))
                            LabeledContent("完成組數", value: "\(record.plan.completedCount) 組")
                            if let duration = record.durationSeconds {
                                LabeledContent("運動時間", value: WorkoutClock.format(duration))
                            }
                        }
                        .font(.subheadline).foregroundStyle(.primary).appCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("record-\(record.id)")
                }
            }.padding(AppDesign.pagePadding)
        }
        .background(.white)
        .navigationTitle("運動紀錄")
    }
}

struct WorkoutRecordView: View {
    let record: WorkoutRecord
    let library: ExerciseLibrary
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    LabeledContent("日期", value: AppDesign.date(record.date))
                    if let duration = record.durationSeconds { LabeledContent("運動時間", value: WorkoutClock.format(duration)) }
                    LabeledContent("完成組數", value: "\(record.plan.completedCount) 組")
                }.font(.subheadline).appCard()
                if record.plan.completedCount == 0 {
                    ContentUnavailableView("沒有完成的組數", systemImage: "checkmark.circle")
                }
                ForEach(record.plan.exercises) { item in
                    if item.sets.contains(where: \.completed) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                if let exercise = library.exercises.first(where: { $0.id == item.exerciseID }) {
                                    ExerciseThumbnail(exercise: exercise)
                                        .frame(width: 64, height: 64)
                                        .background(.white, in: RoundedRectangle(cornerRadius: AppDesign.imageRadius))
                                    Text(exercise.name).font(.headline)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else { Text("動作").font(.headline) }
                            }
                            Divider()
                            ForEach(Array(item.sets.enumerated()), id: \.element.id) { index, set in
                                if set.completed {
                                    LabeledContent("第 \(index + 1) 組", value: "\(set.weight) kg × \(set.repetitions) 次")
                                        .font(.body.monospacedDigit())
                                }
                            }
                        }.appCard()
                    }
                }
            }.padding(AppDesign.pagePadding)
        }
        .background(.white)
        .navigationTitle(record.plan.name).navigationBarTitleDisplayMode(.inline)
    }
}
struct ExercisePicker: View {
    let library: ExerciseLibrary
    let onAdd: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String] = []
    @State private var search = ""
    @State private var category = "全部"

    private var filtered: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.exercises.filter {
            (category == "全部" || $0.category == category) &&
            (query.isEmpty || $0.name.localizedStandardContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["全部"] + ExerciseLibrary.categories, id: \.self) { name in
                            Button { category = name } label: {
                                Text(name).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 18).frame(minHeight: 42)
                                    .foregroundStyle(category == name ? Color.white : Color.primary)
                                    .background(category == name ? Color.black : Color(.systemGray6), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(category == name ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            Color.clear.frame(height: 0).id("picker-top")
                            if filtered.isEmpty {
                                ContentUnavailableView("找不到動作", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity).padding(.top, 32)
                            }
                            ForEach(ExerciseLibrary.categories, id: \.self) { group in
                                let exercises = filtered.filter { $0.category == group }
                                if !exercises.isEmpty {
                                    Text(group).font(.title3.bold())
                                        .padding(.top, 10).padding(.bottom, 2)
                                        .accessibilityAddTraits(.isHeader)
                                    ForEach(exercises) { exercise in
                                        selectionRow(exercise)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: category) { _, _ in proxy.scrollTo("picker-top", anchor: .top) }
                    .onChange(of: search) { _, _ in proxy.scrollTo("picker-top", anchor: .top) }
                }
            }
            .background(.white)
            .navigationTitle("加入動作")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋動作")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    onAdd(selected)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text(selected.isEmpty ? "選擇動作" : "加入 \(selected.count) 個動作")
                        if !selected.isEmpty { Image(systemName: "arrow.right") }
                    }
                    .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 56)
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("confirm-exercise-selection")
                .actionBar()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("取消加入動作")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清除") { selected.removeAll() }.disabled(selected.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private func selectionRow(_ exercise: Exercise) -> some View {
        let index = selected.firstIndex(of: exercise.id)
        return Button {
            if index != nil { selected.removeAll { $0 == exercise.id } }
            else { selected.append(exercise.id) }
        } label: {
            HStack(spacing: 14) {
                ExerciseThumbnail(exercise: exercise)
                    .frame(width: 76, height: 76)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(index == nil ? Color.white : Color.black)
                    if let index {
                        Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(Color(.systemGray3), lineWidth: 1.5)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .padding(12)
            .background(index == nil ? Color(.systemGray6) : Color(red: 0.91, green: 0.94, blue: 1), in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(index == nil ? Color.clear : Color.blue.opacity(0.28), lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(exercise.name)
        .accessibilityValue(index.map { "已選取，第 \($0 + 1) 個動作" } ?? "未選取")
        .accessibilityAddTraits(index == nil ? [] : .isSelected)
        .accessibilityIdentifier("select-exercise-\(exercise.id)")
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
