import SwiftUI
import UserNotifications

/// Punto di ingresso dell'applicazione macOS.
/// Configura il gestore condiviso delle conversioni, il tema grafico, la finestra
/// principale, il pannello delle impostazioni e i comandi aggiunti al menu di sistema.
@main
struct WMA2MP3App: App {
    /// Unica istanza del coordinatore delle conversioni, condivisa con tutte le viste.
    @State private var manager = ConversionManager()
    /// Valore persistente che identifica il tema scelto dall'utente.
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.dark.rawValue
    
    /// Inizializza l'app e richiede a macOS il permesso di mostrare notifiche.
    init() {
        // La richiesta è valida solo quando il programma gira come app bundle e possiede un bundle identifier.
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("Notification authorization error: \(error)")
                }
            }
        } else {
            print("Running without a bundle identifier: Skipping notification authorization.")
        }
    }
    
    /// Dichiara le scene dell'applicazione e costruisce finestra principale e Impostazioni.
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(manager)
                .preferredColorScheme(appearance.colorScheme)
        }
        .commands {
            // Sostituisce la voce standard "Informazioni" con un pannello dotato dell'icona dell'app.
            CommandGroup(replacing: .appInfo) {
                Button("About WMA2MP3") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationIcon: NSImage(named: "AppIcon") ?? NSImage()
                        ]
                    )
                }
            }
        }
        
        Settings {
            SettingsView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }

    /// Converte la stringa salvata nelle preferenze nel corrispondente tema applicativo.
    /// Se il valore non è più valido viene usato il tema scuro come ripiego sicuro.
    private var appearance: AppAppearance {
        AppAppearance(rawValue: appAppearance) ?? .dark
    }
}
