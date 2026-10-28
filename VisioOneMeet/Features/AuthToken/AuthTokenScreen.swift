import SwiftUI

/// auth-token: a plain text page pointing to the code sample
/// (`ProtectedMapSample.swift` + `WebContent/features/auth-token.js`). This
/// demo has no protected map, so nothing is loaded here. See
/// `docs/features/auth-token.md`.
struct AuthTokenScreen: View {
    let feature: Feature

    var body: some View {
        ScrollView {
            Text("feature.auth_token.screen_text")
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle(Text(feature.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}
