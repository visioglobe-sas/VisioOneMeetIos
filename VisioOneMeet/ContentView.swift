import SwiftUI

struct ContentView: View {
    var body: some View {
        MapWebView()
            .ignoresSafeArea()
            .statusBarHidden(false)
    }
}

#Preview {
    ContentView()
}
