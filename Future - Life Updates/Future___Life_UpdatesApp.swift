//___FILEHEADER___

import SwiftData
import SwiftUI

@main
struct Future_Life_UpdatesApp: App {
    @StateObject private var notificationRouter = NotificationRoutingController()

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
                MacOSContentView()
                    .environmentObject(notificationRouter)
                    .task { @MainActor in
                        NotificationCenterDelegate.shared.configure(router: notificationRouter)
                    }
            #else
                ContentView()
                    .environmentObject(notificationRouter)
                    .task { @MainActor in
                        NotificationCenterDelegate.shared.configure(router: notificationRouter)
                    }
            #endif
        }
        .modelContainer(AppEnvironment.shared.modelContainer)
        #if os(macOS)
            .defaultSize(width: 900, height: 700)
            .windowResizability(.contentSize)
        #endif
    }
}
