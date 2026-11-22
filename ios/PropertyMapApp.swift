import SwiftUI

@main
struct PropertyMapApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Map", systemImage: "map") }
                SubscriptionView()
                    .tabItem { Label("Plans", systemImage: "crown") }
            }
        }
    }
}
