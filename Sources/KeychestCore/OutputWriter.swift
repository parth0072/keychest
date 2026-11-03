import Foundation

public enum OutputWriter {
    /// Writes generated files under `directory`. Existing files with the same names are overwritten;
    /// nothing else in the directory is touched or deleted.
    @discardableResult
    public static func write(_ files: [GeneratedFile], to directory: String) throws -> [String] {
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        var written: [String] = []
        do {
            for file in files {
                let url = root.appendingPathComponent(file.path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try Data(file.contents.utf8).write(to: url, options: .atomic)
                written.append(url.path)
            }
        } catch {
            throw KeychestError.writeFailure(error.localizedDescription)
        }
        return written
    }
}
