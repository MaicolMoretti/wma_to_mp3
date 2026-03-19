import SwiftUI
import UserNotifications

@main
struct WMA2MP3App: App {
    @State private var manager = ConversionManager()
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
        }
        .commands {
            // Add settings to menu
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
        }
    }
}
