import SwiftUI

struct ContentView: View {
    @State private var favorites = FavoriteExercises()
    @State private var selectedTab = "首頁"
    @State private var plans = WorkoutPlanStore()
    @State private var rest = RestTimer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            RestTimerBar()
            Group {
                switch ExerciseLibrary.bundled {
                case .success(let library):
                    TabView(selection: $selectedTab) {
                        Tab("首頁", systemImage: "house", value: "首頁") {
                            navigationRoot(library: library) { CategorySelection(library: library) }
                        }
                        Tab("健身計劃", systemImage: "list.bullet.clipboard", value: "健身計劃") {
                            WorkoutPlansView(library: library)
                        }
                        Tab("收藏", systemImage: "heart", value: "收藏") {
                            navigationRoot(library: library) { FavoritesView(library: library) }
                        }
                    }
                case .failure:
                    ContentUnavailableView("無法讀取動作", systemImage: "exclamationmark.triangle", description: Text("請重新安裝 App 後再試一次。"))
                }
            }
        }
        .environment(favorites)
        .environment(plans)
        .environment(rest)
        .onChange(of: scenePhase) { _, phase in rest.setScene(phase) }
        .tint(.primary)
        .preferredColorScheme(.light)
    }

    private func navigationRoot<Content: View>(library: ExerciseLibrary, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: WorkoutCategory.self) { category in
                    CategoryExercises(category: category, library: library)
                }
                .navigationDestination(for: Exercise.self) { ExerciseDetail(exercise: $0) }
        }
    }
}

private struct CategorySelection: View {
    let library: ExerciseLibrary
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("選擇訓練部位")
                    .font(.system(.title, design: .default).weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 12)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                    ForEach(WorkoutCategory.all) { category in
                        NavigationLink(value: category) {
                            VStack(spacing: 6) {
                                BundledArtwork(name: category.asset)
                                    .scaledToFit()
                                    .frame(height: 140)
                                    .frame(maxWidth: .infinity)
                                    .background(.white)
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.bottom, 15)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.black.opacity(0.06)))
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(category.name)
                        .accessibilityIdentifier("category-\(category.asset)")
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .background { GymBackground() }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct CategoryExercises: View {
    let category: WorkoutCategory
    let library: ExerciseLibrary
    @State private var filter = "全部"
    private let filters = ["全部", "槓鈴", "啞鈴", "機械", "徒手"]
    private var exercises: [Exercise] {
        library.exercises.filter { $0.category == category.name && (filter == "全部" || $0.equipmentFilter == filter) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geometry in
                        BundledArtwork(name: category.cover)
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    Text(category.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(24)
                }
                .frame(height: 235)
                .accessibilityAddTraits(.isHeader)

                VStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { option in
                                Button { filter = option } label: {
                                    Text(option)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 17)
                                        .frame(minHeight: 40)
                                        .foregroundStyle(filter == option ? Color(.systemBackground) : Color.primary)
                                        .background(filter == option ? Color.primary : Color(.tertiarySystemFill), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(filter == option ? .isSelected : [])
                                .accessibilityIdentifier("filter-\(option)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                    if exercises.isEmpty {
                        ContentUnavailableView("沒有符合的動作", systemImage: "line.3.horizontal.decrease", description: Text("選擇其他器材以查看動作。"))
                            .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(exercises) { exercise in
                                NavigationLink(value: exercise) { ExerciseRow(exercise: exercise) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("exercise-\(exercise.id)")
                                if exercise.id != exercises.last?.id { Divider().padding(.leading, 128) }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .background { GymBackground() }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                .padding(.top, -12)
            }
        }
        .background { GymBackground() }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    var body: some View {
        HStack(spacing: 16) {
            ExerciseThumbnail(exercise: exercise)
                .frame(width: 90, height: 82)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(exercise.level)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(exercise.levelColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(exercise.levelColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct ExerciseThumbnail: View {
    let exercise: Exercise
    var body: some View {
        if let url = exercise.thumbnailURL, let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

private struct FavoritesView: View {
    let library: ExerciseLibrary
    @Environment(FavoriteExercises.self) private var favorites
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let items = library.exercises.filter { favorites.contains($0) }
                if items.isEmpty {
                    ContentUnavailableView("尚未收藏動作", systemImage: "heart", description: Text("在動作頁點選愛心，即可加入收藏。"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    ForEach(items) { exercise in
                        NavigationLink(value: exercise) { ExerciseRow(exercise: exercise) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("exercise-\(exercise.id)")
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .navigationTitle("收藏")
        .toolbar(.visible, for: .navigationBar)
        .background { GymBackground() }
    }
}

struct ExerciseDetail: View {
    let exercise: Exercise
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var animation: GIFAnimation?
    @State private var failed = false
    @State private var isPlaying = false
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(exercise.name)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    MuscleTags(exercise: exercise)
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        BundledArtwork(name: exercise.workoutCategory.asset)
                            .scaledToFill()
                            .frame(width: 110, height: 218)
                            .clipped()
                            .background(.white)
                            .accessibilityLabel("\(exercise.category)肌群示意")
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let animation {
                                    GIFPlayer(animation: animation, isPlaying: isPlaying && isVisible && scenePhase == .active)
                                        .frame(width: 180, height: 180)
                                        .accessibilityElement()
                                        .accessibilityLabel("\(exercise.name)動作示範")
                                } else if failed {
                                    Text("無法載入示範").foregroundStyle(.black)
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if animation != nil {
                                Button { isPlaying.toggle() } label: {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 46, height: 46)
                                        .background(Color.black.opacity(0.8), in: Circle())
                                }
                                .padding(10)
                                .accessibilityLabel(isPlaying ? "暫停" : "播放")
                                .accessibilityIdentifier("playback-toggle")
                            }
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(height: 218)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 8) { metadata }
                    VStack(alignment: .leading, spacing: 8) { metadata }
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("動作步驟").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(.systemBackground))
                                .frame(minWidth: 27, minHeight: 27)
                                .background(Color.primary, in: Circle())
                                .accessibilityHidden(true)
                            Text(step)
                                .font(.subheadline)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("步驟 \(index + 1)，\(step)")
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background { GymBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(.primary)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { FavoriteButton(exercise: exercise) } }
        .task {
            guard animation == nil, !failed else { return }
            do {
                guard let url = exercise.gifURL else { throw CocoaError(.fileNoSuchFile) }
                animation = try GIFAnimation(url: url)
            } catch { failed = true }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: reduceMotion) { _, reduced in if reduced { isPlaying = false } }
    }

    private var metadata: some View {
        Group {
            DetailMetric(symbol: "chart.bar", title: "難度", value: exercise.level)
            DetailMetric(symbol: "dumbbell", title: "器材", value: exercise.equipment)
            DetailMetric(symbol: "figure.strengthtraining.traditional", title: "目標", value: exercise.goal)
        }
    }
}

private struct DetailMetric: View {
    let symbol: String
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol).font(.subheadline).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.secondary)
                Text(value).fontWeight(.medium).fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

#Preview { ContentView() }
