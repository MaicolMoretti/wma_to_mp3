import Foundation
import Observation
import SwiftUI

/// Represents the quality of the output MP3 file in kbps.
enum MP3Quality: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case q128 = 128
    case q192 = 192
    case q256 = 256
    case q320 = 320
    
    var id: Int { self.rawValue }
    
    var description: String {
        return "\(self.rawValue) kbps"
    }
}

/// Represents the different states of a file conversion.
enum ConversionState: Equatable {
    case pending
    case converting(progress: Double)
    case done
    case error(message: String)
}

/// Model representing a single WMA file added to the queue for conversion.
@Observable
final class AudioFile: Identifiable, Hashable {
    let id: UUID
    let sourceURL: URL
    var destinationURL: URL?
    var state: ConversionState
    var originalSize: Int64
    var errorMessage: String?
    
    init(sourceURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.state = .pending
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        self.originalSize = attributes?[.size] as? Int64 ?? 0
    }
    
    var filename: String {
        sourceURL.lastPathComponent
    }
    
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// App settings model persisted automatically via AppStorage.
struct AppSettings {
    @AppStorage("mp3Quality") var mp3Quality: Int = 192
    @AppStorage("overwriteExisting") var overwriteExisting: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("customOutputFolder") var customOutputFolderData: Data?
    
    var customOutputFolderURL: URL? {
        get {
            guard let data = customOutputFolderData else { return nil }
            var isStale = false
            return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        set {
            if let url = newValue {
                customOutputFolderData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            } else {
                customOutputFolderData = nil
            }
        }
    }
}
