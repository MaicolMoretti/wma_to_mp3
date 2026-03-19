import Foundation

enum FileHelpers {
    static func generateUniqueFilename(for target: URL) -> URL {
        let dir = target.deletingLastPathComponent()
        let name = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        
        var index = 1
        var newURL = target
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = dir.appendingPathComponent("\(name)_\(index)").appendingPathExtension(ext)
            index += 1
        }
        return newURL
    }
}
