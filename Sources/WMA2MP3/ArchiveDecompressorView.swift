import SwiftUI
import UniformTypeIdentifiers

/// Flusso grafico completo per selezionare, estrarre e riepilogare più archivi.
struct ArchiveDecompressorView: View {
    /// Manager locale che conserva coda, avanzamento e risultati.
    @State private var manager = DecompressorManager()
    /// Stato di evidenziazione della zona di trascinamento.
    @State private var isTargeted = false
    /// Callback usata per tornare al menu principale.
    var onBack: () -> Void
    
    /// Seleziona la schermata appropriata in base allo stato del manager.
    var body: some View {
        VStack(spacing: 0) {
            header
            
            VStack(spacing: 20) {
                if manager.state == .completed {
                    completionScreen
                } else if manager.state == .processing {
                    processingScreen
                } else {
                    selectionScreen
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.05))
            .onDrop(of: [.item, .fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
    }
    
    /// Intestazione con titolo e comando di navigazione indietro.
    private var header: some View {
        HStack {
            Button(action: onBack) {
                Label("Indietro", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .padding()
            
            Spacer()
            Text("Decompressore Archivi")
                .font(.headline)
                .padding()
            Spacer()
            Color.clear.frame(width: 60)
        }
        .background(.ultraThinMaterial)
    }
    
    /// Schermata di selezione degli archivi e della cartella di destinazione.
    @ViewBuilder
    private var selectionScreen: some View {
        VStack(spacing: 30) {
            // Zona di trascinamento con indicazione dei formati accettati.
            VStack(spacing: 20) {
                Image(systemName: "doc.zipper")
                    .font(.system(size: 64))
                    .foregroundColor(isTargeted ? .accentColor : .green)
                
                Text(manager.archives.isEmpty ? "Trascina qui gli archivi" : "\(manager.archives.count) file selezionati")
                    .font(.title2)
                    .bold()
                
                Text("Supporta ZIP, RAR, 7Z, TAR, TAR.GZ, ecc.")
                    .foregroundColor(.secondary)
                
                Button("Seleziona Archivi...") {
                    selectFiles()
                }
                .buttonStyle(.bordered)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isTargeted ? Color.green : Color.green.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .background(Color.green.opacity(isTargeted ? 0.1 : 0.0))
            )
            .padding(.horizontal, 40)
            
            if !manager.archives.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("Cartella di Destinazione:")
                            .font(.headline)
                        Spacer()
                        Text(manager.outputFolder?.path ?? "Nessuna selezionata")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Button("Sfoglia...") { selectOutputFolder() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    
                    if case let .error(msg) = manager.state {
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button("Decompress and Merge") {
                        Task { await manager.startProcessing() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
            }
        }
    }
    
    /// Schermata con archivio corrente, stima, log e annullamento.
    @ViewBuilder
    private var processingScreen: some View {
        VStack(spacing: 30) {
            Text("Estrazione in corso...")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                let currentTotal = manager.archives.count
                let currentIdx = manager.currentProcessingIndex + 1
                Text("Elaborazione archivio \(currentIdx) di \(currentTotal)")
                    .font(.headline)
                
                if currentIdx - 1 < manager.archives.count {
                    Text(manager.archives[currentIdx - 1].url.lastPathComponent)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                ProgressView(value: manager.extractionPercentage)
                    .progressViewStyle(.linear)
                
                HStack {
                    Text("\(Int(manager.extractionPercentage * 100))%")
                    Spacer()
                    if manager.estimatedRemainingSeconds > 0 {
                        Text("Stima rimamente: \(DecompressorManager.formatDuration(manager.estimatedRemainingSeconds))")
                    } else {
                        Text("Calcolo del tempo stimato...")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 10)
            .padding(.horizontal, 40)
            
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(manager.logMessages.suffix(10), id: \.self) { msg in
                        Text(msg)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(height: 100)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(8)
            .padding(.horizontal, 40)
            
            Button("Annulla") {
                manager.cancelProcessing()
            }
            .buttonStyle(.bordered)
        }
    }
    
    /// Riepilogo finale con statistiche e collegamento al Finder.
    @ViewBuilder
    private var completionScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Completato!")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Archivi Processati:")
                    Spacer()
                    Text("\(manager.totalArchivesProcessed) (Successi: \(manager.successCount), Errori: \(manager.failureCount))")
                        .bold()
                }
                Divider()
                HStack {
                    Text("File Estratti ed Uniti:")
                    Spacer()
                    Text("\(manager.totalFilesExtracted)")
                        .bold()
                }
                Divider()
                HStack {
                    Text("Cartella di Destinazione:")
                    Spacer()
                    Text(manager.outputFolder?.path ?? "")
                        .bold()
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(30)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(16)
            .padding(.horizontal, 40)
            
            HStack(spacing: 20) {
                Button("Mostra nel Finder") {
                    if let folder = manager.outputFolder {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Nuova Estrazione") {
                    manager.reset()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Azioni
    
    /// Raccoglie in modo asincrono gli URL trascinati e filtra i formati supportati.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let exts = ["zip", "rar", "7z", "tar", "gz", "bz2", "tgz"]
        var droppedUrls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data = data,
                      let path = NSString(data: data, encoding: 4),
                      let url = URL(string: path as String) else { return }
                
                let ext = url.pathExtension.lowercased()
                if exts.contains(ext) || ext == "" {
                    droppedUrls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            if !droppedUrls.isEmpty {
                manager.addArchives(droppedUrls)
            }
        }
        return true
    }
    
    /// Apre il pannello di selezione multipla degli archivi.
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        // Limita il pannello ai formati di archivio più comuni.
        panel.allowedContentTypes = [
            UTType.archive,
            UTType.zip,
            UTType(filenameExtension: "bz2") ?? UTType.data,
            UTType.gzip,
            UTType(filenameExtension: "rar") ?? UTType.data,
            UTType(filenameExtension: "7z") ?? UTType.data,
            UTType(filenameExtension: "tar") ?? UTType.data
        ]
        
        if panel.runModal() == .OK {
            manager.addArchives(panel.urls)
        }
    }
    
    /// Consente di scegliere o creare la cartella che riceverà i file estratti.
    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            manager.outputFolder = url
        }
    }
}
