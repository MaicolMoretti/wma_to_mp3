import Foundation

enum FFmpegError: Error, LocalizedError {
    case binaryNotFound
    case processFailed(Int)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound: return String(localized: "FFmpeg binary not found.")
        case .processFailed(let code): return String(localized: "Conversion failed with error code \(code).")
        case .cancelled: return String(localized: "Conversion was cancelled.")
        }
    }
}

actor FFmpegEngine {
    private var process: Process?
    
    /// Prepares arguments and parses progress via stdout/stderr, reporting back via the callback.
    func convert(source: URL, destination: URL, quality: Int, progressHandler: @escaping (Double) -> Void) async throws {
        guard let ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) else {
            throw FFmpegError.binaryNotFound
        }
        
        let p = Process()
        process = p
        p.executableURL = ffmpegURL
        
        // ffmpeg -y -i input.wma -codec:a libmp3lame -b:a 192k -map_metadata 0 output.mp3
        p.arguments = [
            "-y", // Overwrite output files
            "-i", source.path,
            "-codec:a", "libmp3lame",
            "-b:a", "\(quality)k",
            "-map_metadata", "0",
            destination.path
        ]
        
        let errorPipe = Pipe()
        p.standardError = errorPipe
        
        // We need to parse duration from stderr first, then time
        // Example: Duration: 00:03:12.45
        // Example: size=    3072kB time=00:01:30.12 bitrate= 279.1kbits/s
        
        let fileHandle = errorPipe.fileHandleForReading
        
        try p.run()
        
        var totalDuration: Double? = nil
        
        for try await line in fileHandle.bytes.lines {
            if Task.isCancelled {
                p.terminate()
                throw FFmpegError.cancelled
            }
            
            if totalDuration == nil, let durationStr = extractRegex(pattern: "Duration: ?(\\d+:\\d+:\\d+\\.\\d+)", from: line) {
                totalDuration = parseTime(durationStr)
            }
            
            if let total = totalDuration, let timeStr = extractRegex(pattern: "time=(\\d+:\\d+:\\d+\\.\\d+)", from: line) {
                let time = parseTime(timeStr)
                let progress = min(max(time / total, 0.0), 1.0)
                progressHandler(progress)
            }
        }
        
        p.waitUntilExit()
        
        if Task.isCancelled || p.terminationStatus == 9 || p.terminationStatus == 15 {
            throw FFmpegError.cancelled
        }
        
        if p.terminationStatus != 0 {
            throw FFmpegError.processFailed(Int(p.terminationStatus))
        }
        
        // Ensure 100% on success
        progressHandler(1.0)
        self.process = nil
    }
    
    func cancel() {
        process?.terminate()
    }
    
    private func extractRegex(pattern: String, from string: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = string as NSString
        let results = regex?.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))
        guard let first = results?.first, first.numberOfRanges > 1 else { return nil }
        return nsString.substring(with: first.range(at: 1))
    }
    
    private func parseTime(_ timeString: String) -> Double {
        // HH:MM:SS.SS
        let parts = timeString.split(separator: ":")
        guard parts.count == 3 else { return 0 }
        
        let h = Double(parts[0]) ?? 0
        let m = Double(parts[1]) ?? 0
        let s = Double(parts[2]) ?? 0
        
        return (h * 3600) + (m * 60) + s
    }
}
