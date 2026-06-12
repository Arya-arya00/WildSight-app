import SwiftUI

@main
struct QiyuBookApp: App {
    @StateObject private var store = EncounterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
