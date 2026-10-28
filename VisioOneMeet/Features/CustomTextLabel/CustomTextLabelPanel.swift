import SwiftUI

/// Places free text on the map via `venue.createLabel()` next to an anchor
/// POI, restyles it live via `venue.updateLabel()` (text, color, size) and
/// removes it via `venue.removeLabel()` -- see
/// docs/features/custom-text-label.md. A rotation change recreates the
/// label, since `rotation` is only accepted at creation. After a successful
/// place, the camera moves to the anchor POI via goto-poi's
/// `bridge.goToPOI`, same as 3d-icon-marker. Empty text or an
/// unknown/position-less anchor POI is shown as a plain status line, not a
/// crash.
struct CustomTextLabelPanel: View {
    @ObservedObject var model: CustomTextLabelModel
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var size: Binding<TextLabelSize> {
        Binding(get: { model.size }, set: { model.setSize($0) })
    }

    private var rotation: Binding<Int> {
        Binding(get: { model.rotation }, set: { model.setRotation($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PoiIdField("Anchor POI ID", text: $model.anchorPoiId)
                    .disabled(isBusy)

                TextField("Text", text: $model.text)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .disabled(isBusy)

                Text("Color")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(TextLabelColor.allCases) { color in
                        ColorSwatchChip(
                            name: Self.name(color),
                            hex: color.rawValue,
                            isSelected: model.color == color
                        ) {
                            model.setColor(color)
                        }
                    }
                }

                Text("Size")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("Size", selection: size) {
                    Text("Small").tag(TextLabelSize.small)
                    Text("Medium").tag(TextLabelSize.medium)
                    Text("Large").tag(TextLabelSize.large)
                }
                .pickerStyle(.segmented)

                Text("Rotation")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("Rotation", selection: rotation) {
                    ForEach(CustomTextLabelModel.rotations, id: \.self) { degrees in
                        Text(verbatim: "\(degrees)\u{00B0}").tag(degrees)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Place label") {
                        place()
                    }
                    .disabled(isBusy || model.trimmedAnchorPoiId.isEmpty)

                    Button("Update text") {
                        updateText()
                    }
                    .disabled(isBusy || !model.hasLabel)

                    Button("Remove label", role: .destructive) {
                        errorMessage = nil
                        model.remove()
                    }
                    .disabled(!model.hasLabel)
                }
                .buttonStyle(.bordered)

                statusText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private static func name(_ color: TextLabelColor) -> LocalizedStringKey {
        switch color {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .dark: return "Dark"
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let anchorId = model.placedAnchorId {
            Text("Label placed on \(anchorId)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("No label placed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func place() {
        let anchor = model.trimmedAnchorPoiId
        guard !anchor.isEmpty else { return }

        isBusy = true
        errorMessage = nil

        Task {
            let result = await model.place(anchorId: anchor)
            isBusy = false
            if result == .success {
                // A label is only drawn when its POI's floor is displayed:
                // reuse goto-poi's camera move (floor switch +
                // view.goToPOI), same as 3d-icon-marker.
                model.bridge.goToPOI(anchor)
            } else {
                errorMessage = placedObjectErrorMessage(result, isBadge: false)
            }
        }
    }

    private func updateText() {
        isBusy = true
        errorMessage = nil

        Task {
            let result = await model.updateText()
            isBusy = false
            errorMessage = placedObjectErrorMessage(result, isBadge: false)
        }
    }
}
