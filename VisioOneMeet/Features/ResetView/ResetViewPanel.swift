import SwiftUI

struct ResetViewPanel: View {
    let model: ResetViewModel

    var body: some View {
        Button {
            model.bridge.goToGlobal()
        } label: {
            Text("feature.reset_view.title")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
}
