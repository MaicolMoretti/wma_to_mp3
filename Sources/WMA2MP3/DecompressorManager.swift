import Foundation
import Observation

@Observable
/// Gestisce la selezione, l'estrazione sequenziale e l'unione di più archivi.
final class DecompressorManager {
    /// Stato globale del flusso di decompressione.
    enum State: Equatable {
        case idle
        case processing
        case completed
        case error(String)
    }
    
    /// Descrive un archivio della coda e il suo avanzamento individuale.
    struct ArchiveItem: Identifiable {
        /// Identificatore stabile per le collezioni SwiftUI.
        let id = UUID()
        /// Percorso dell'archivio sorgente.
        let url: URL
        /// Dimensione usata per stimare l'avanzamento complessivo.
        let size: Int64
        /// Stato corrente dell'archivio.
        var status: Status = .pending
        
        /// Fasi possibili dell'elaborazione di un singolo archivio.
        enum Status: Equatable {
            case pending
            case processing
            case completed(filesExtracted: Int)
            case error(String)
        }
    }
    
    /// Stato osservato dalla vista principale del decompressore.
    var state: State = .idle
    /// Archivi selezionati dall'utente.
    var archives: [ArchiveItem] = []
    
    /// Cartella nella quale vengono uniti tutti i contenuti estratti.
    var outputFolder: URL?
    
    // Valori di avanzamento mostrati durante l'elaborazione.
    var currentProcessingIndex: Int = 0
    var totalFilesExtracted: Int = 0
    var extractionPercentage: Double = 0.0
    var estimatedRemainingSeconds: Double = 0.0
    
    /// Messaggi diagnostici visualizzati nel pannello di log.
    var logMessages: [String] = []
    
    // Statistiche aggregate mostrate nella schermata finale.
    var totalArchivesProcessed: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    
    /// Totale dei byte degli archivi, base della stima percentuale.
    private var totalBytesToProcess: Int64 = 0
    /// Byte attribuiti agli archivi già terminati.
    private var bytesProcessed: Int64 = 0
    /// Istante iniziale usato per stimare il tempo residuo.
    private var startTime: Date?
    
    /// Aggiunge archivi non duplicati e propone automaticamente una cartella di output.
    func addArchives(_ urls: [URL]) {
        for url in urls {
            // Evita che lo stesso percorso venga elaborato più volte.
            if !archives.contains(where: { $0.url == url }) {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                archives.append(ArchiveItem(url: url, size: Int64(size)))
            }
        }
        
        // Per impostazione iniziale crea "Extracted_Files" accanto al primo archivio.
        if outputFolder == nil, let first = archives.first {
            outputFolder = first.url.deletingLastPathComponent().appendingPathComponent("Extracted_Files")
        }
    }
    
    /// Ripristina integralmente manager, statistiche e selezione iniziale.
    func reset() {
        state = .idle
        archives.removeAll()
        outputFolder = nil
        currentProcessingIndex = 0
        totalFilesExtracted = 0
        extractionPercentage = 0.0
        estimatedRemainingSeconds = 0.0
        logMessages.removeAll()
        totalArchivesProcessed = 0
        successCount = 0
        failureCount = 0
        totalBytesToProcess = 0
        bytesProcessed = 0
    }
    
    /// Interrompe il ciclo dopo l'archivio corrente e segnala l'annullamento alla vista.
    func cancelProcessing() {
        if state == .processing {
            log("Operazione annullata dall'utente.")
            state = .error("Operazione annullata.")
        }
    }
    
    /// Registra un messaggio sia nella UI sia nella console di debug.
    private func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
            print("[Decompressor] \(message)")
        }
    }
    
    /// Crea la destinazione ed estrae in sequenza tutti gli archivi selezionati.
    func startProcessing() async {
        guard !archives.isEmpty else { return }
        guard let outputDir = outputFolder else {
            state = .error("Nessuna cartella di destinazione selezionata.")
            return
        }
        
        state = .processing
        totalArchivesProcessed = 0
        successCount = 0
        failureCount = 0
        totalFilesExtracted = 0
        currentProcessingIndex = 0
        
        // Calcola una stima basata sul peso relativo di ciascun archivio.
        totalBytesToProcess = archives.reduce(0) { $0 + $1.size }
        bytesProcessed = 0
        startTime = Date()
        
        // La cartella viene creata una sola volta prima di avviare strumenti esterni.
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: outputDir.path) {
                try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
            }
        } catch {
            state = .error("Impossibile creare la cartella di destinazione: \(error.localizedDescription)")
            return
        }
        
        for i in archives.indices {
            // Esce al primo cambio di stato, per esempio dopo un annullamento dell'utente.
            if state != .processing { break }
            
            archives[i].status = .processing
            currentProcessingIndex = i
            let item = archives[i]
            
            log("Inizio estrazione: \(item.url.lastPathComponent)")
            
            do {
                let extractedCount = try await extractArchive(item.url, to: outputDir)
                archives[i].status = .completed(filesExtracted: extractedCount)
                
                DispatchQueue.main.async {
                    self.totalFilesExtracted += extractedCount
                    self.successCount += 1
                }
                log("Completato: \(item.url.lastPathComponent) (\(extractedCount) file estratti)")
            } catch {
                let errMsg = "Errore \(item.url.lastPathComponent): \(error.localizedDescription)"
                archives[i].status = .error(errMsg)
                log(errMsg)
                DispatchQueue.main.async {
                    self.failureCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.bytesProcessed += item.size
                self.updateProgress()
                self.totalArchivesProcessed += 1
            }
        }
        
        if state == .processing {
            log("Processo terminato. Successi: \(successCount), Errori: \(failureCount)")
            state = .completed
        }
    }
    
    /// Aggiorna percentuale e tempo residuo usando la velocità media dall'avvio.
    private func updateProgress() {
        if totalBytesToProcess > 0 {
            extractionPercentage = min(1.0, Double(bytesProcessed) / Double(totalBytesToProcess))
        } else {
            extractionPercentage = 1.0
        }
        
        if let start = startTime, bytesProcessed > 0 {
            let elapsed = Date().timeIntervalSince(start)
            let speed = Double(bytesProcessed) / elapsed
            let remainingBytes = Double(totalBytesToProcess - bytesProcessed)
            if speed > 0 {
                estimatedRemainingSeconds = remainingBytes / speed
            }
        }
    }
    
    /// Estrae un archivio in una cartella temporanea e ne fonde poi il contenuto nell'output.
    /// Restituisce il numero di file regolari estratti.
    private func extractArchive(_ archiveURL: URL, to destURL: URL) async throws -> Int {
        // Una directory isolata evita collisioni fra archivi durante l'estrazione.
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // La directory temporanea viene rimossa sia in caso di successo sia di errore.
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let ext = archiveURL.pathExtension.lowercased()
        
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // `unzip` gestisce i file ZIP; `tar` di macOS delega gli altri formati a libarchive.
        if ext == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", archiveURL.path, "-d", tempDir.path]
        } else {
            // bsdtar supporta TAR e, in base a libarchive, anche RAR, 7Z e formati compressi.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archiveURL.path, "-C", tempDir.path]
        }
        
        try process.run()
        process.waitUntilExit()
        
        // Propaga stderr nel messaggio mostrato all'utente quando il comando fallisce.
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Errore sconosciuto"
            throw NSError(domain: "ArchiveDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Estrazione fallita. \(output)"])
        }
        
        let extractedFiles = countFiles(at: tempDir)
        try mergeContents(from: tempDir, to: destURL)
        return extractedFiles
    }
    
    /// Conta ricorsivamente soltanto i file, escludendo cartelle ed elementi nascosti.
    private func countFiles(at url: URL) -> Int {
        var count = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
            for case let file as URL in enumerator {
                if let isDir = try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, !isDir {
                    count += 1
                }
            }
        }
        return count
    }
    
    /// Sposta ricorsivamente gli elementi estratti, unendo cartelle omonime.
    private func mergeContents(from sourceDir: URL, to destDir: URL) throws {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        
        for item in items {
            let destURL = destDir.appendingPathComponent(item.lastPathComponent)
            
            // Se sorgente e destinazione sono cartelle, ne unisce ricorsivamente il contenuto.
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: destURL.path, isDirectory: &isDir) {
                var srcIsDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &srcIsDir) {
                    if isDir.boolValue && srcIsDir.boolValue {
                        try mergeContents(from: item, to: destURL)
                        try? fm.removeItem(at: item)
                        continue
                    }
                }
                
                // File o cartelle incompatibili vengono rinominati senza sovrascrivere dati.
                let uniqueURL = generateUniqueURL(for: destURL, isDirectory: srcIsDir.boolValue)
                try fm.moveItem(at: item, to: uniqueURL)
            } else {
                try fm.moveItem(at: item, to: destURL)
            }
        }
    }
    
    /// Genera un percorso libero aggiungendo un contatore tra parentesi al nome originale.
    private func generateUniqueURL(for url: URL, isDirectory: Bool) -> URL {
        let fm = FileManager.default
        var uniqueURL = url
        var counter = 1
        
        let pathExt = isDirectory ? "" : url.pathExtension
        let name = isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        let directory = url.deletingLastPathComponent()
        
        while fm.fileExists(atPath: uniqueURL.path) {
            let newName = "\(name)_(\(counter))"
            if isDirectory || pathExt.isEmpty {
                uniqueURL = directory.appendingPathComponent(newName)
            } else {
                uniqueURL = directory.appendingPathComponent(newName).appendingPathExtension(pathExt)
            }
            counter += 1
        }
        
        return uniqueURL
    }
    
    /// Formatta una durata in `MM:SS` oppure `HH:MM:SS` per la schermata di avanzamento.
    static func formatDuration(_ seconds: Double) -> String {
        if seconds < 0 || seconds.isNaN { return "00:00" }
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        if m > 60 {
            let h = m / 60
            let min = m % 60
            return String(format: "%02d:%02d:%02d", h, min, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
