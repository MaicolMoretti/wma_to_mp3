import Foundation
import Observation
import SwiftUI

/// Elenca i bitrate MP3 selezionabili, espressi in kilobit al secondo.
enum MP3Quality: Int, CaseIterable, Identifiable, CustomStringConvertible {
    /// Qualità compatta, adatta a ridurre la dimensione del file.
    case q128 = 128
    /// Qualità predefinita, buon compromesso fra fedeltà e spazio occupato.
    case q192 = 192
    /// Qualità elevata.
    case q256 = 256
    /// Qualità massima disponibile nell'interfaccia.
    case q320 = 320
    
    /// Usa il bitrate come identificatore stabile nelle liste SwiftUI.
    var id: Int { self.rawValue }
    
    /// Testo leggibile visualizzato nel selettore delle impostazioni.
    var description: String {
        return "\(self.rawValue) kbps"
    }
}

/// Definisce il tema cromatico applicato a tutte le finestre dell'app.
enum AppAppearance: String, CaseIterable, Identifiable {
    /// Forza l'interfaccia scura.
    case dark
    /// Forza l'interfaccia chiara.
    case light
    /// Delega la scelta del tema alle preferenze di macOS.
    case system

    /// Identificatore persistibile usato da `AppStorage` e da SwiftUI.
    var id: String { rawValue }

    /// Etichetta italiana mostrata nel selettore del tema.
    var title: String {
        switch self {
        case .dark: "Scuro"
        case .light: "Chiaro"
        case .system: "Sistema"
        }
    }

    /// Traduce la preferenza nel `ColorScheme` di SwiftUI; `nil` segue macOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// Rappresenta tutte le fasi possibili della conversione di un singolo file.
enum ConversionState: Equatable {
    /// File in coda, non ancora elaborato.
    case pending
    /// Conversione attiva con avanzamento normalizzato tra zero e uno.
    case converting(progress: Double)
    /// Conversione terminata correttamente.
    case done
    /// Conversione fallita; il valore associato contiene il messaggio diagnostico.
    case error(message: String)
}

/// Modello osservabile di un file audio inserito nella coda di conversione.
@Observable
final class AudioFile: Identifiable, Hashable {
    /// Identificatore univoco dell'elemento, indipendente dal suo percorso.
    let id: UUID
    /// Posizione del file audio originale.
    let sourceURL: URL
    /// Posizione del file MP3 prodotto, disponibile dopo la scelta della destinazione.
    var destinationURL: URL?
    /// Stato corrente dell'elaborazione.
    var state: ConversionState
    /// Dimensione originale in byte, usata dall'interfaccia.
    var originalSize: Int64
    /// Eventuale dettaglio tecnico dell'ultimo errore.
    var errorMessage: String?
    
    /// Crea il modello e legge, quando possibile, la dimensione del file dal filesystem.
    init(sourceURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.state = .pending
        
        // La lettura non deve impedire l'aggiunta: se fallisce la dimensione viene posta a zero.
        let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        self.originalSize = attributes?[.size] as? Int64 ?? 0
    }
    
    /// Nome completo del file sorgente, senza il percorso delle cartelle.
    var filename: String {
        sourceURL.lastPathComponent
    }
    
    /// Due elementi sono uguali quando condividono lo stesso identificatore.
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Inserisce l'identificatore nell'hasher, coerentemente con l'operatore di uguaglianza.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Preferenze dell'applicazione persistite automaticamente tramite `AppStorage`.
struct AppSettings {
    /// Bitrate MP3 selezionato, in kbps.
    @AppStorage("mp3Quality") var mp3Quality: Int = 192
    /// Indica se un file di destinazione esistente può essere sostituito.
    @AppStorage("overwriteExisting") var overwriteExisting: Bool = false
    /// Abilita la notifica macOS al termine del lotto.
    @AppStorage("showNotifications") var showNotifications: Bool = true
    /// Bookmark di sicurezza serializzato della cartella di output personalizzata.
    @AppStorage("customOutputFolder") var customOutputFolderData: Data?
    
    /// Espone il bookmark persistito come URL utilizzabile dal convertitore.
    var customOutputFolderURL: URL? {
        get {
            guard let data = customOutputFolderData else { return nil }
            var isStale = false
            // Risolve il bookmark e consente a macOS di segnalare se è diventato obsoleto.
            return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        set {
            // Salva un bookmark security-scoped; assegnando nil si ripristina la cartella sorgente.
            if let url = newValue {
                customOutputFolderData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            } else {
                customOutputFolderData = nil
            }
        }
    }
}
