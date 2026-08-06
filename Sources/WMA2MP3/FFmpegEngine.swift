import Foundation

/// Errori specifici prodotti dall'avvio o dall'esecuzione di FFmpeg.
enum FFmpegError: Error, LocalizedError {
    case binaryNotFound
    case processFailed(Int)
    case cancelled
    
    /// Messaggio localizzabile presentabile all'utente.
    var errorDescription: String? {
        switch self {
        case .binaryNotFound: return String(localized: "FFmpeg binary not found.")
        case .processFailed(let code): return String(localized: "Conversion failed with error code \(code).")
        case .cancelled: return String(localized: "Conversion was cancelled.")
        }
    }
}

/// Incapsula un singolo processo FFmpeg e ne serializza l'accesso concorrente.
actor FFmpegEngine {
    /// Processo attivo, conservato per poterlo terminare su richiesta.
    private var process: Process?
    
    /// Prepara gli argomenti, esegue FFmpeg e comunica l'avanzamento tramite callback.
    func convert(source: URL, destination: URL, quality: Int, progressHandler: @escaping (Double) -> Void) async throws {
        guard let ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) else {
            throw FFmpegError.binaryNotFound
        }
        
        let p = Process()
        process = p
        p.executableURL = ffmpegURL
        
        // Compone il comando: sovrascrittura, codec MP3, bitrate scelto e copia dei metadati.
        p.arguments = [
            "-y", // Consente a FFmpeg di sovrascrivere il percorso già autorizzato dal manager.
            "-i", source.path,
            "-codec:a", "libmp3lame",
            "-b:a", "\(quality)k",
            "-map_metadata", "0",
            destination.path
        ]
        
        let errorPipe = Pipe()
        p.standardError = errorPipe
        
        // FFmpeg scrive su stderr prima la durata totale e poi il tempo elaborato corrente.
        // Esempi: `Duration: 00:03:12.45` e `time=00:01:30.12`.
        
        let fileHandle = errorPipe.fileHandleForReading
        
        try p.run()
        
        var totalDuration: Double? = nil
        
        for try await line in fileHandle.bytes.lines {
            // La cancellazione cooperativa termina anche il processo di sistema sottostante.
            if Task.isCancelled {
                p.terminate()
                throw FFmpegError.cancelled
            }
            
            // La durata totale viene acquisita una sola volta dall'intestazione dell'output.
            if totalDuration == nil, let durationStr = extractRegex(pattern: "Duration: ?(\\d+:\\d+:\\d+\\.\\d+)", from: line) {
                totalDuration = parseTime(durationStr)
            }
            
            // Il rapporto fra tempo elaborato e durata produce un valore limitato a 0...1.
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
        
        // Garantisce che la UI raggiunga il 100% anche se manca l'ultima riga di progresso.
        progressHandler(1.0)
        self.process = nil
    }
    
    /// Termina il processo FFmpeg eventualmente in esecuzione.
    func cancel() {
        process?.terminate()
    }
    
    /// Restituisce il primo gruppo catturato da un'espressione regolare.
    private func extractRegex(pattern: String, from string: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = string as NSString
        let results = regex?.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))
        guard let first = results?.first, first.numberOfRanges > 1 else { return nil }
        return nsString.substring(with: first.range(at: 1))
    }
    
    /// Converte una durata `HH:MM:SS.ss` nel numero totale di secondi.
    private func parseTime(_ timeString: String) -> Double {
        // Le componenti non numeriche vengono trattate come zero in modo difensivo.
        let parts = timeString.split(separator: ":")
        guard parts.count == 3 else { return 0 }
        
        let h = Double(parts[0]) ?? 0
        let m = Double(parts[1]) ?? 0
        let s = Double(parts[2]) ?? 0
        
        return (h * 3600) + (m * 60) + s
    }
}
