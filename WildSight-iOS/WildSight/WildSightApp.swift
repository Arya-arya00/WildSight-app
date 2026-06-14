import SwiftUI

@main
struct WildSightApp: App {
    @StateObject private var store = EncounterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
