/// Soccer_DraftApp.swift
///
/// The app entry point. Sets up the root SwiftUI scene, hosts ContentView,
/// and applies the user's preferred color scheme (light, dark, or system),
/// reacting to changes in the UserDefaults "colorSchemeMode" key.
import SwiftUI

@main
/// The app's root `App` type, launched by SwiftUI. It owns the window group,
/// monitors color scheme preference changes, and renders `ContentView`.
struct Soccer_DraftApp: App {
    /// The persisted color scheme mode ("light", "dark", or "system"),
    /// read from UserDefaults and kept in sync with external changes.
    @State private var colorSchemeMode: String = UserDefaults.standard.string(forKey: "colorSchemeMode") ?? "system"

    /// The root scene content. Shows `ContentView` and updates the applied
    /// color scheme whenever the stored preference changes.
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

    /// Converts the stored mode string into a `ColorScheme` to apply.
    /// Returns `nil` for the default "system" mode.
    private var colorScheme: ColorScheme? {
        switch colorSchemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
