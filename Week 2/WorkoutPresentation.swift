import SwiftUI

struct WorkoutCategory: Identifiable, Hashable {
    let name: String
    let asset: String
    let accent: Color
    var id: String { name }
    var cover: String { asset.replacingOccurrences(of: "anatomy-", with: "cover-") }

    static let all: [WorkoutCategory] = [
        .init(name: "胸", asset: "anatomy-chest", accent: .orange),
        .init(name: "背", asset: "anatomy-back", accent: .blue),
        .init(name: "肩膀", asset: "anatomy-shoulders", accent: .orange),
        .init(name: "腿", asset: "anatomy-legs", accent: .green),
        .init(name: "二三頭", asset: "anatomy-arms", accent: .purple),
        .init(name: "核心", asset: "anatomy-core", accent: .yellow)
    ]
}

extension Exercise {
    var workoutCategory: WorkoutCategory { WorkoutCategory.all.first { $0.name == category } ?? WorkoutCategory.all[0] }
    var muscleTags: [String] { muscles.components(separatedBy: "、") }
    var equipmentFilter: String {
        if equipment.contains("啞鈴") { return "啞鈴" }
        if equipment.contains("槓鈴") { return "槓鈴" }
        if equipment.contains("徒手") || equipment == "單槓" || id == "0620" { return "徒手" }
        return "機械"
    }
    var level: String {
        if ["0652", "0027", "0043", "0085", "0464", "0251", "1326", "0410", "0472"].contains(id) { return "中階" }
        if ["3470", "0274", "0276", "1373"].contains(id) { return "初階" }
        return "基礎"
    }
    var levelColor: Color {
        switch level {
        case "中階": return .orange
        case "初階": return .green
        default: return .blue
        }
    }
    var goal: String { category == "核心" ? "核心穩定" : "肌力訓練" }
}

@Observable
final class FavoriteExercises {
    private static let key = "fitness.favoriteExerciseIDs"
    private(set) var ids: Set<String> = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])

    func contains(_ exercise: Exercise) -> Bool { ids.contains(exercise.id) }
    func toggle(_ exercise: Exercise) {
        if ids.contains(exercise.id) { ids.remove(exercise.id) } else { ids.insert(exercise.id) }
        UserDefaults.standard.set(ids.sorted(), forKey: Self.key)
    }
}

struct BundledArtwork: View {
    let name: String
    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"), let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable()
        }
    }
}

struct MuscleTags: View {
    let exercise: Exercise
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) { tags }
            VStack(alignment: .leading, spacing: 5) { tags }
        }
    }
    private var tags: some View {
        ForEach(Array(exercise.muscleTags.enumerated()), id: \.offset) { index, muscle in
            Text(muscle)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(index == 0 ? exercise.workoutCategory.accent.opacity(0.16) : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct FavoriteButton: View {
    let exercise: Exercise
    @Environment(FavoriteExercises.self) private var favorites
    var body: some View {
        Button { favorites.toggle(exercise) } label: {
            Image(systemName: favorites.contains(exercise) ? "heart.fill" : "heart")
                .font(.system(size: 21, weight: .regular))
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(favorites.contains(exercise) ? "取消收藏" : "收藏動作")
        .accessibilityIdentifier("favorite-\(exercise.id)")
    }
}
