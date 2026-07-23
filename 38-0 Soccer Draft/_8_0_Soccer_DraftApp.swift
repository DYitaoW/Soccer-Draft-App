//
//  _8_0_Soccer_DraftApp.swift
//  38-0 Soccer Draft
//
//  Created by Dylan Wang on 7/22/26.
//

import SwiftUI
import SwiftData

@main
struct _8_0_Soccer_DraftApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
