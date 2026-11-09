import XCTest
@testable import KeychestCore

final class ExamplesTests: XCTestCase {
    func testEveryExampleConfigIsValid() throws {
        let examples = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Examples")
        let files = try FileManager.default.contentsOfDirectory(at: examples, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "yml" }
        XCTAssertGreaterThanOrEqual(files.count, 4)
        for file in files {
            XCTAssertNoThrow(try Config.load(from: file.path), file.lastPathComponent)
        }
    }
}
