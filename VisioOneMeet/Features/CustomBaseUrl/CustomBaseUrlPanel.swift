import SwiftUI

/// Lets the user retype the SDK's own `LoadOptions.baseURL` and reload the
/// venue against it. Two normal outcomes: the pre-filled default value
/// reloads exactly like every other feature's map already does (proving the
/// parameter is genuinely wired through the bridge, not just a UI stub), and
/// a garbage/unreachable value surfaces the SDK's own typed
/// `VenueNotFoundError` -- rendered by the feature screen's existing
/// `.error(message)` overlay, the same one every feature already falls back
/// to on a bad hash, no new error UI needed here. See
/// docs/features/custom-base-url.md.
struct CustomBaseUrlPanel: View {
    let bridge: VisioOneBridge
    @State private var baseURL: String

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        _baseURL = State(initialValue: bridge.pageOptions.baseURL ?? CustomBaseUrlModel.sdkDefaultBaseURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Base URL")
                .font(.headline)

            TextField("Base URL", text: $baseURL)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            Button("Reload") {
                let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                bridge.reloadWithBaseURL(trimmed)
            }
            .disabled(baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}
