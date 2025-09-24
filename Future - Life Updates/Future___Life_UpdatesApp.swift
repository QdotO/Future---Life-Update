//___FILEHEADER___

import SwiftUI
import SwiftData

@main
struct Future_Life_UpdatesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AppEnvironment.shared.modelContainer)
    }
}
