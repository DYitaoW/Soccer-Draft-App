import SwiftUI

@main
struct Soccer_DraftApp: App {
    @State private var colorSchemeMode: String = UserDefaults.standard.string(forKey: "colorSchemeMode") ?? "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                    let newValue = UserDefaults.standard.string(forKey: "colorSchemeMode") ?? "system"
                    if newValue != colorSchemeMode {
                        colorSchemeMode = newValue
                    }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch colorSchemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
