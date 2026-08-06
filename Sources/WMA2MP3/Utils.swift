import Foundation

/// Raccolta di funzioni pure e riutilizzabili per la gestione dei percorsi su disco.
enum FileHelpers {
    /// Restituisce un URL libero senza sovrascrivere file esistenti.
    /// Se `target` esiste già, aggiunge progressivamente `_1`, `_2` e così via al nome.
    static func generateUniqueFilename(for target: URL) -> URL {
        // Separa cartella, nome ed estensione per poter ricostruire le varianti numerate.
        let dir = target.deletingLastPathComponent()
        let name = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        
        var index = 1
        var newURL = target
        // Continua a incrementare il suffisso finché non trova un percorso non occupato.
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = dir.appendingPathComponent("\(name)_\(index)").appendingPathExtension(ext)
            index += 1
        }
        return newURL
    }
}
