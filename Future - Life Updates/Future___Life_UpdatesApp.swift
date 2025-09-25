//___FILEHEADER___

import SwiftUI
import SwiftData

@main
struct Future_Life_UpdatesApp: App {
    @StateObject private var notificationRouter = NotificationRoutingController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationRouter)
                .task { @MainActor in
                    NotificationCenterDelegate.shared.configure(router: notificationRouter)
                }
        }
        .modelContainer(AppEnvironment.shared.modelContainer)
    }
}
