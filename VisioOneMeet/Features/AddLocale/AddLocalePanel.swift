import SwiftUI

/// Lets the user add a brand-new `'es'` (Spanish) locale at runtime via
/// `venue.translator.addLocale('es', resources)` -- one never authored in
/// VisioMapEditor for this map, unlike the `en`/`fr` runtime-locale switches
/// between. Shows each of `AddLocaleModel.keys` with "(not added yet)" until
/// `model.spanishTranslations` is populated, then the real value read back
/// via `translate(key, 'es')` -- the primary, always-working proof the round
/// trip succeeded, regardless of the SDK's own UI visibility. The optional
/// "Switch to Spanish" button reuses runtime-locale's exact
/// `setCurrentLocale` call so any visible SDK UI text updates live too -- a
/// bonus, not the main proof, hence disabled until the locale has actually
/// been added. See docs/features/add-locale.md.
struct AddLocalePanel: View {
    @ObservedObject var model: AddLocaleModel
    @State private var isAdding = false
    @State private var isSwitching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(AddLocaleModel.keys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Group {
                            if let value = model.spanishTranslations?[key] {
                                Text(verbatim: value)
                            } else {
                                Text("(not added yet)")
                            }
                        }
                            .font(.body)
                            .foregroundStyle(model.spanishTranslations == nil ? .secondary : .primary)
                    }
                }
            }

            Button(model.spanishTranslations == nil ? "Add Spanish locale" : "Re-add Spanish locale" as LocalizedStringKey) {
                addLocale()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(isAdding)

            Button("Switch to Spanish") {
                switchToSpanish()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .disabled(isSwitching || model.spanishTranslations == nil)
        }
        .padding()
    }

    private func addLocale() {
        isAdding = true
        Task {
            await model.addSpanishLocale()
            isAdding = false
        }
    }

    private func switchToSpanish() {
        isSwitching = true
        Task {
            await model.switchToSpanish()
            isSwitching = false
        }
    }
}
