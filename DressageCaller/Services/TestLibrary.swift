import Foundation

/// Persists user-imported dressage tests as JSON files in `Documents/tests/`.
@MainActor
@Observable
final class TestLibrary {
    private(set) var tests: [DressageTest] = []
    private let directory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("tests", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        tests = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(DressageTest.self, from: data)
            }
            .sorted { $0.name < $1.name }
    }

    func save(_ test: DressageTest) throws {
        let data = try JSONEncoder().encode(test)
        let file = directory.appendingPathComponent("\(test.id.uuidString).json")
        try data.write(to: file, options: .atomic)
        load()
    }

    func delete(_ test: DressageTest) throws {
        let file = directory.appendingPathComponent("\(test.id.uuidString).json")
        try FileManager.default.removeItem(at: file)
        load()
    }
}
