import Foundation
import AVFoundation
import SwiftUI
import Observation

/// Semaforo asincrono robusto per controllare il parallelismo.
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) { count = limit }
    
    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }
    
    func signal() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            count += 1
        }
    }
}

//autore: Maicol Moretti
/// Gestore della segmentazione video basata su cue visive.
@Observable
final class VideoSegmentationManager {
    
    enum ProcessingState: Equatable {
        case idle
        case scanning(progress: Double)
        case cutting(progress: Double)
        case completed(count: Int)
        case error(String)
    }
    
    var state: ProcessingState = .idle
    var statusMessage: String = ""
    var log: String = ""
    var elapsedSeconds: Double = 0
    var estimatedTotalSeconds: Double = 0
    private var scanStartTime: Date = Date()
    
    /// Avvia il processo di segmentazione per il file video fornito.
    func processVideo(url: URL) async {
        statusMessage = "Caricamento video..."
        state = .scanning(progress: 0)
        log = "Inizio scansione video: \(url.lastPathComponent)\n"
        
        let asset = AVAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            state = .error("Impossibile caricare la durata del video.")
            statusMessage = "Errore caricamento."
            return
        }
        
        let durationSeconds = CMTimeGetSeconds(duration)
        if durationSeconds == 0 {
            state = .error("Video non valido o di durata zero.")
            statusMessage = "Errore: Durata zero."
            return
        }
        
        // 1. Scansione fotogrammi per trovare i delimiter
        statusMessage = "Scansione fotogrammi per rilevamento schermate blu..."
        let delimiterTimestamps = await findBlueScreenDelimiters(asset: asset, durationSeconds: durationSeconds)
        
        if delimiterTimestamps.isEmpty {
            log += "ERRORE: Nessuna schermata blu rilevata dopo la scansione completa.\n"
            state = .error("Nessun punto di segmentazione (schermata blu) rilevato.")
            statusMessage = "Nessun segmento trovato."
            return
        }
        
        statusMessage = "Analisi completata. Rilevati \(delimiterTimestamps.count) segmenti. Preparazione per il taglio..."
        log += "Analisi completata. Rilevati \(delimiterTimestamps.count) segmenti.\n"
        
        // 2. Definizione dei segmenti (timestamp inizio/fine)
        var segments: [(start: Double, end: Double)] = []
        for i in 0..<delimiterTimestamps.count {
            let start = delimiterTimestamps[i]
            let end = (i + 1 < delimiterTimestamps.count) ? delimiterTimestamps[i+1] : durationSeconds
            segments.append((start, end))
        }
        
        // 3. Esecuzione dei tagli tramite ffmpeg
        log += "Inizio fase di taglio con FFmpeg...\n"
        await cutSegments(sourceURL: url, segments: segments)
    }
    
    /// Trova i timestamp delle schermate blu campionando il video.
    /// Usa AVAssetImageGenerator in modalità batch e TaskGroup per sfruttare
    /// tutto il parallelismo disponibile su CPU e GPU.
    private func findBlueScreenDelimiters(asset: AVAsset, durationSeconds: Double) async -> [Double] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // PERFORMANCE: tolleranza 0.5s invece di .zero — permette seek al keyframe più vicino
        // invece di decodificare ogni frame dalla radice. Circa 10-20x più veloce su H.264/HEVC.
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        // Richiedi risoluzione 640x360 per mantenere leggibile il testo bianco sfocato (anti-aliased)
        // contro il blu scuro dello sfondo durante il downscaling, altrimenti diventa grigio.
        generator.maximumSize = CGSize(width: 640, height: 360)
        
        // Campionameno ogni 1 secondo
        let samplerate: Double = 1.0
        var times: [CMTime] = []
        for t in stride(from: 0, to: durationSeconds, by: samplerate) {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
        }
        
        let totalCount = times.count
        scanStartTime = Date()
        
        // Struttura per raccogliere i risultati in modo thread-safe
        actor ResultCollector {
            var results: [(time: Double, isBlue: Bool)] = []
            var processedCount: Int = 0
            func add(time: Double, isBlue: Bool) {
                results.append((time: time, isBlue: isBlue))
                processedCount += 1
            }
        }
        let collector = ResultCollector()
        
        // PERFORMANCE: Genera e analizza frame in parallelo con TaskGroup.
        // Ogni core CPU lavora su un frame diverso contemporaneamente.
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        await withTaskGroup(of: Void.self) { group in
            // Semaforo per limitare il numero di decode parallele (evita OOM)
            let semaphore = AsyncSemaphore(limit: coreCount * 2)
            
            for cmTime in times {
                await semaphore.wait()
                group.addTask {
                    do {
                        let (image, _) = try await generator.image(at: cmTime)
                        let isBlue = VideoAnalyzer.isBlueScreen(image)
                        let t = CMTimeGetSeconds(cmTime)
                        await collector.add(time: t, isBlue: isBlue)
                        
                        let processed = await collector.processedCount
                        let progress = Double(processed) / Double(totalCount)
                        let elapsed = Date().timeIntervalSince(self.scanStartTime)
                        let eta = progress > 0.01 ? elapsed / progress : 0
                        let etaRemaining = max(0, eta - elapsed)
                        await MainActor.run {
                            self.state = .scanning(progress: progress)
                            self.elapsedSeconds = elapsed
                            self.estimatedTotalSeconds = eta
                            let percent = Int(progress * 100)
                            self.statusMessage = "Scansione \(percent)% — Trascorso: \(Self.formatDuration(elapsed)) — Rimanente: ~\(Self.formatDuration(etaRemaining))"
                        }
                    } catch {
                        await collector.add(time: CMTimeGetSeconds(cmTime), isBlue: false)
                    }
                    await semaphore.signal()
                }
            }
        }
        
        // Ordina per timestamp e trova le transizioni non-blu → blu
        let sorted = await collector.results.sorted { $0.time < $1.time }
        var rawDelimiters: [Double] = []
        var lastWasBlue = false
        for result in sorted {
            if result.isBlue && !lastWasBlue {
                rawDelimiters.append(result.time)
            }
            lastWasBlue = result.isBlue
        }
        
        // --- CLUSTERING LOGIC ---
        // A blue screen usually lasts 3-5 seconds. Due to relaxed thresholds, 
        // the detection might flicker (e.g. True, False, True, True) within the same blue screen,
        // triggering multiple delimiters. We group any delimiters closer than 15s.
        var clusteredDelimiters: [Double] = []
        for d in rawDelimiters {
            if let last = clusteredDelimiters.last {
                if d - last < 15.0 {
                    // Ignore: too close to the previous delimiter (same blue screen)
                    print("DEBUG: Ignorato delimitatore a \(d)s (troppo vicino al precedente a \(last)s)")
                    continue
                }
            }
            clusteredDelimiters.append(d)
            print("DEBUG: Confermato delimitatore a \(d)s")
        }
        
        return clusteredDelimiters
    }


    static func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }

    /// Taglia il video in segmenti usando ffmpeg in modo sicuro.
    private func cutSegments(sourceURL: URL, segments: [(start: Double, end: Double)]) async {
        let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) ?? "/usr/local/bin/ffmpeg"
        
        guard FileManager.default.fileExists(atPath: ffmpegPath) else {
            await MainActor.run {
                self.state = .error("Componente FFmpeg non trovato.")
            }
            return
        }

        let fileManager = FileManager.default
        let directory = sourceURL.deletingLastPathComponent()
        let filenameBase = sourceURL.deletingPathExtension().lastPathComponent
        
        for (index, segment) in segments.enumerated() {
            let partNumber = index + 1
            let outputName = "\(filenameBase)_part\(partNumber).mp4"
            let outputURL = directory.appendingPathComponent(outputName)
            
            // Rimozione sicura del file esistente
            if fileManager.fileExists(atPath: outputURL.path) {
                try? fileManager.removeItem(at: outputURL)
            }
            
            let duration = segment.end - segment.start
            let startTimeStr = String(format: "%.3f", segment.start)
            let durationStr = String(format: "%.3f", duration)
            
            await MainActor.run {
                self.state = .cutting(progress: Double(partNumber) / Double(segments.count))
                self.statusMessage = "Taglio parte \(partNumber) di \(segments.count)..."
                self.log += "Esportazione parte \(partNumber) (\(startTimeStr)s)...\n"
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            // Sicurezza: Argomenti passati come array evitando shell injection
            process.arguments = [
                "-y", "-threads", "0",
                "-ss", startTimeStr,
                "-t", durationStr,
                "-i", sourceURL.path,
                "-c", "copy",
                "-avoid_negative_ts", "make_zero",
                outputURL.path
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            do {
                try process.run()
                
                // Timeout di sicurezza: 10 minuti per segmento
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 600 * 1_000_000_000)
                    if process.isRunning {
                        process.terminate()
                    }
                }
                
                for try await line in pipe.fileHandleForReading.bytes.lines {
                    let logLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !logLine.isEmpty else { continue }
                    
                    if logLine.contains("frame=") || logLine.contains("size=") {
                        continue // Non intasiamo il log con progressi tecnici
                    }
                    
                    await MainActor.run {
                        self.log += logLine + "\n"
                        if self.log.count > 4000 {
                            self.log = String(self.log.suffix(2000))
                        }
                    }
                }
                
                process.waitUntilExit()
                timeoutTask.cancel()
                
                if process.terminationStatus != 0 {
                    print("FFmpeg error status: \(process.terminationStatus)")
                }
            } catch {
                await MainActor.run {
                    self.log += "Errore processo: \(error.localizedDescription)\n"
                }
            }
        }
        
        await MainActor.run {
            self.state = .completed(count: segments.count)
            self.statusMessage = "Completato con successo!"
            self.log += "Processo terminato con successo.\n"
        }
    }
    
    func reset() {
        state = .idle
        statusMessage = ""
        log = ""
        elapsedSeconds = 0
        estimatedTotalSeconds = 0
    }
}
