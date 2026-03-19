import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class ConversionManager {
    var files: [AudioFile] = []
    var isConverting: Bool = false
    var overallProgress: Double = 0.0
    
    private var engineTasks: [UUID: FFmpegEngine] = [:]
    private var conversionTaskGroup: Task<Void, Never>?
    
    func addFile(_ url: URL) {
        guard !files.contains(where: { $0.sourceURL == url }) else { return }
        let newFile = AudioFile(sourceURL: url)
        files.append(newFile)
    }
    
    func removeFile(_ id: UUID) {
        files.removeAll(where: { $0.id == id })
    }
    
    func clearDone() {
        files.removeAll(where: { $0.state == .done })
    }
    
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
    
    func startConversion(settings: AppSettings) {
        guard !files.isEmpty else { return }
        isConverting = true
        
        // Reset states
        for file in files {
            if file.state == .done || (file.state == .error(message: "") && false) {
                // Keep done files done, reset errors if needed
            } else {
                file.state = .pending
                file.errorMessage = nil
            }
        }
        
        updateProgress()
        
        conversionTaskGroup = Task(priority: .userInitiated) {
            await runBatch(settings: settings)
            self.isConverting = false
            self.updateProgress()
            if settings.showNotifications {
                self.showCompletionNotification()
            }
        }
    }
    
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
            // Wait for remaining tasks to complete
            await group.waitForAll()
        }
    }
    
    private func convertSingle(_ file: AudioFile, settings: AppSettings) async {
        let sourceURL = file.sourceURL
        
        // Output Directory
        let outputDir = settings.customOutputFolderURL ?? sourceURL.deletingLastPathComponent()
        
        // Edge Case: Read-Only output directory? Wait,FileManager attributes can check if writable,
        // but it's simpler to catch the error from FFmpeg or creating the file.
        
        // Edge Case: 0-byte source file
        if file.originalSize == 0 {
            file.state = .error(message: String(localized: "Source file is empty (0 bytes)."))
            return
        }
        
        var destURL = outputDir.appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent).appendingPathExtension("mp3")
        
        if FileManager.default.fileExists(atPath: destURL.path) && !settings.overwriteExisting {
            destURL = FileHelpers.generateUniqueFilename(for: destURL)
        }
        
        file.destinationURL = destURL
        
        if Task.isCancelled {
            file.state = .error(message: String(localized: "Cancelled"))
            return
        }
        
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
            // If it failed and we created an empty file, clean it up
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
        }
        
        engineTasks.removeValue(forKey: file.id)
    }
    
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
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
