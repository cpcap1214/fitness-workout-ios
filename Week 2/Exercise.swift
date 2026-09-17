import Foundation

struct Exercise: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let equipment: String
    let muscles: String
    let steps: [String]
    let gifFile: String
    let thumbnailFile: String
    let attribution: String
    let translationNote: String

    var gifURL: URL? { Bundle.main.url(forResource: gifFile, withExtension: nil) }
    var thumbnailURL: URL? { Bundle.main.url(forResource: thumbnailFile, withExtension: nil) }
    var remoteThumbnailURL: URL? {
        URL(string: "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/7455efae41b330c265e7cd4b78dfa848e7ce5ebd/images/")?
            .appendingPathComponent(thumbnailFile)
    }
}

struct ExerciseLibrary {
    static let categories = ["胸", "背", "肩膀", "腿", "二三頭", "核心"]
    let exercises: [Exercise]

    static let bundled: Result<ExerciseLibrary, Error> = Result {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let exercises = try JSONDecoder().decode([Exercise].self, from: Data(contentsOf: url))
        guard exercises.count == 60,
              Set(exercises.map(\.id)).count == 60,
              categories.allSatisfy({ category in exercises.filter { $0.category == category }.count == 10 }),
              exercises.allSatisfy({ !$0.steps.isEmpty && $0.gifURL != nil && $0.thumbnailURL != nil }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return ExerciseLibrary(exercises: exercises)
    }
}
