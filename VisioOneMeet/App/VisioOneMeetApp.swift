import SwiftUI

@main
struct VisioOneMeetApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .navigationDestination(for: Feature.self) { feature in
                FeatureScreen(feature: feature)
            }
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
        }
    }
}
