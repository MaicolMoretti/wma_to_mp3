import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
/// Coordina la coda, l'esecuzione concorrente e l'avanzamento delle conversioni audio.
/// L'isolamento al `MainActor` rende sicuri gli aggiornamenti osservati dalle viste SwiftUI.
final class ConversionManager {
    /// File attualmente presenti nella coda.
    var files: [AudioFile] = []
    /// Indica se è in esecuzione almeno un lotto di conversione.
    var isConverting: Bool = false
    /// Avanzamento complessivo normalizzato tra zero e uno.
    var overallProgress: Double = 0.0
    
    /// Associa ogni file al motore FFmpeg attivo, così da poterlo annullare.
    private var engineTasks: [UUID: FFmpegEngine] = [:]
    /// Task principale che mantiene in vita il lotto corrente.
    private var conversionTaskGroup: Task<Void, Never>?
    
    /// Inserisce un file nella coda, ignorando percorsi già presenti.
    func addFile(_ url: URL) {
        guard !files.contains(where: { $0.sourceURL == url }) else { return }
        let newFile = AudioFile(sourceURL: url)
        files.append(newFile)
    }
    
    /// Rimuove dalla coda il file con l'identificatore indicato.
    func removeFile(_ id: UUID) {
        files.removeAll(where: { $0.id == id })
    }
    
    /// Elimina dalla lista tutti gli elementi convertiti correttamente.
    func clearDone() {
        files.removeAll(where: { $0.state == .done })
    }
    
    /// Annulla il lotto e inoltra la richiesta a ogni processo FFmpeg attivo.
    func cancel() {
        conversionTaskGroup?.cancel()
        for engine in engineTasks.values {
            Task {
                await engine.cancel()
            }
        }
        isConverting = false
        updateProgress()
    }
    
    /// Prepara gli stati della coda e avvia un nuovo lotto con le preferenze correnti.
    func startConversion(settings: AppSettings) {
        guard !files.isEmpty else { return }
        isConverting = true
        
        // Reimposta solo i file non completati, conservando i risultati già prodotti.
        for file in files {
            if file.state == .done || (file.state == .error(message: "") && false) {
                // I file completati restano tali; il secondo ramo è riservato a future politiche sugli errori.
            } else {
                file.state = .pending
                file.errorMessage = nil
            }
        }
        
        updateProgress()
        
        // Il task ad alta priorità esegue il lotto e, al termine, aggiorna UI e notifiche.
        conversionTaskGroup = Task(priority: .userInitiated) {
            await runBatch(settings: settings)
            self.isConverting = false
            self.updateProgress()
            if settings.showNotifications {
                self.showCompletionNotification()
            }
        }
    }
    
    /// Distribuisce i file pendenti su un numero di task non superiore ai core disponibili.
    private func runBatch(settings: AppSettings) async {
        let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount
        
        await withTaskGroup(of: Void.self) { group in
            var activeTasks = 0
            
            for file in self.files where file.state == .pending {
                if activeTasks >= maxConcurrent {
                    await group.next()
                    activeTasks -= 1
                }
                
                guard !Task.isCancelled else { break }
                
                group.addTask {
                    await self.convertSingle(file, settings: settings)
                }
                activeTasks += 1
            }
            // Attende anche gli ultimi task rimasti nel gruppo.
            await group.waitForAll()
        }
    }
    
    /// Converte un singolo file, determina la destinazione e gestisce errori e pulizia.
    private func convertSingle(_ file: AudioFile, settings: AppSettings) async {
        let sourceURL = file.sourceURL
        
        // Usa la cartella personalizzata oppure quella del file sorgente.
        let outputDir = settings.customOutputFolderURL ?? sourceURL.deletingLastPathComponent()
        
        // Un file vuoto non è convertibile e viene scartato prima di avviare un processo esterno.
        if file.originalSize == 0 {
            file.state = .error(message: String(localized: "Source file is empty (0 bytes)."))
            return
        }
        
        var destURL = outputDir.appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent).appendingPathExtension("mp3")
        
        // Evita collisioni quando la sovrascrittura è disabilitata.
        if FileManager.default.fileExists(atPath: destURL.path) && !settings.overwriteExisting {
            destURL = FileHelpers.generateUniqueFilename(for: destURL)
        }
        
        file.destinationURL = destURL
        
        if Task.isCancelled {
            file.state = .error(message: String(localized: "Cancelled"))
            return
        }
        
        // Registra il motore prima dell'avvio per rendere immediatamente disponibile l'annullamento.
        let engine = FFmpegEngine()
        engineTasks[file.id] = engine
        
        do {
            try await engine.convert(source: sourceURL, destination: destURL, quality: settings.mp3Quality) { progress in
                Task { @MainActor in
                    file.state = .converting(progress: progress)
                    self.updateProgress()
                }
            }
            if !Task.isCancelled {
                file.state = .done
            }
        } catch {
            file.state = .error(message: error.localizedDescription)
            // Rimuove l'eventuale output incompleto lasciato da una conversione fallita.
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
        }
        
        engineTasks.removeValue(forKey: file.id)
    }
    
    /// Ricalcola la percentuale globale combinando file conclusi e avanzamenti parziali.
    private func updateProgress() {
        let done = files.filter { $0.state == .done }.count
        let error = files.filter { if case .error = $0.state { return true } else { return false }}.count
        
        let convertingFiles = files.filter {
            if case .converting = $0.state { return true }
            return false
        }
        
        let total = files.count
        guard total > 0 else {
            overallProgress = 0.0
            return
        }
        
        var currentProgressSum = Double(done + error) * 1.0
        
        for file in convertingFiles {
            if case .converting(let progress) = file.state {
                currentProgressSum += progress
            }
        }
        
        overallProgress = currentProgressSum / Double(total)
    }
    
    
    /// Costruisce e invia la notifica macOS con il riepilogo del lotto.
    private func showCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Conversion Complete")
        
        let successCount = files.filter({ $0.state == .done }).count
        let errorCount = files.filter({ if case .error = $0.state { return true }; return false }).count
        
        if errorCount > 0 {
            content.body = String(localized: "Converted \(successCount) files. \(errorCount) failed.")
        } else {
            content.body = String(localized: "Successfully converted \(successCount) files.")
        }
        content.sound = UNNotificationSound.default
        
        if Bundle.main.bundleIdentifier != nil {
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            print("Running without a bundle identifier: Skipping notification request.")
        }
    }
}
