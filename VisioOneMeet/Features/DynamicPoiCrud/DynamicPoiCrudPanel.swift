import SwiftUI

/// Lets the user create, edit the label text of, and remove a single
/// "dynamic" POI at runtime, without republishing the map in VisioMapEditor
/// -- see docs/features/dynamic-poi-crud.md. Three fields (New POI ID,
/// Anchor POI ID, Label text) plus Create/Update text/Remove actions.
///
/// Only one dynamic POI is tracked at a time (`model.dynamicPOI`) -- the
/// simplest demo state. Create is disabled whenever one is already tracked;
/// a duplicate id (`POIAlreadyExistsError` on the SDK side) and an
/// unresolved/position-less anchor POI are shown as plain inline states,
/// not crashes.
struct DynamicPoiCrudPanel: View {
    @ObservedObject var model: DynamicPoiCrudModel
    @State private var isCreating = false
    @State private var createError: String?

    private var hasDynamicPOI: Bool { model.dynamicPOI != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                statusText

                PoiIdField("New POI ID", text: $model.newPoiId)
                    .disabled(hasDynamicPOI || isCreating)

                PoiIdField("Anchor POI ID", text: $model.anchorPoiId)
                    .disabled(hasDynamicPOI || isCreating)

                TextField("Label text", text: $model.labelText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isCreating)

                if let createError {
                    Text(createError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Create") {
                        create()
                    }
                    .disabled(hasDynamicPOI || isCreating || model.trimmedNewPoiId.isEmpty || model.trimmedAnchorPoiId.isEmpty || model.trimmedLabelText.isEmpty)

                    Button("Update text") {
                        model.updateText()
                    }
                    .disabled(!hasDynamicPOI || model.trimmedLabelText.isEmpty)

                    Button("Remove", role: .destructive) {
                        createError = nil
                        model.remove()
                    }
                    .disabled(!hasDynamicPOI)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if let dynamicPOI = model.dynamicPOI {
            Text("Created: \(dynamicPOI.id) — \"\(dynamicPOI.labelText)\"")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("No dynamic POI created yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func create() {
        let id = model.trimmedNewPoiId
        let anchor = model.trimmedAnchorPoiId
        let text = model.trimmedLabelText
        guard !id.isEmpty, !anchor.isEmpty, !text.isEmpty else { return }

        isCreating = true
        createError = nil

        Task {
            let result = await model.create(newId: id, anchorId: anchor, labelText: text)
            isCreating = false
            switch result {
            case .success:
                break
            case .duplicate:
                createError = String(localized: "A POI with id \"\(id)\" already exists")
            case .poiNotFound:
                createError = String(localized: "Anchor POI \"\(anchor)\" not found")
            case .noPosition:
                createError = String(localized: "Anchor POI has no position to copy")
            default:
                createError = String(localized: "Could not create the POI")
            }
        }
    }
}
