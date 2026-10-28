import SwiftUI

/// Lets the user switch the map's displayed language (POI/label text) at
/// runtime via `venue.setCurrentLocale()`, no reload/republish needed --
/// see docs/features/runtime-locale.md. Reads the venue's current locale
/// once (`model.currentLocale`, kept on the model so it survives the sheet
/// being dismissed and reopened), then shows a checkmark next to whichever
/// of the two offered options matches it.
struct RuntimeLocalePanel: View {
    @ObservedObject var model: RuntimeLocaleModel
    @State private var isSwitching = false

    var body: some View {
        List(RuntimeLocaleModel.options) { option in
            Button {
                switchLocale(to: option.code)
            } label: {
                HStack {
                    Text(option.label)
                    Spacer()
                    if option.code == model.currentLocale {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.primary)
            .disabled(isSwitching || option.code == model.currentLocale)
        }
        .listStyle(.plain)
        .task {
            guard model.currentLocale == nil else { return }
            await model.refreshCurrentLocale()
        }
    }

    private func switchLocale(to code: String) {
        isSwitching = true
        Task {
            await model.switchLocale(to: code)
            isSwitching = false
        }
    }
}
