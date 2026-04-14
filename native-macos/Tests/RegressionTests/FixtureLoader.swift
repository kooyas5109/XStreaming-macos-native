import Foundation

enum Fixtures {
    static func load(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Fixtures").appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
}
