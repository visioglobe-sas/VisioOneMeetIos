import SwiftUI

/// Lets the user type a POI ID and load its business CustomData (free
/// key/value strings such as price, opening hours, product reference), via
/// `venue.refreshCustomData()` + `venue.getPOICustomData()`. A single "Load"
/// button runs both SDK calls in sequence -- goto-poi/clickable-surface's
/// idiom of one field + one action, rather than splitting "refresh" and
/// "look up" into two separate buttons, since the cache almost always needs
/// refreshing right before a lookup anyway. See docs/features/custom-data.md.
struct CustomDataPanel: View {
    @ObservedObject var model: CustomDataModel
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            knownPlaceIdChips

            HStack {
                PoiIdField("Place ID", text: $model.poiId)
                    .disabled(isLoading)

                Button("Load") {
                    load()
                }
                .disabled(isLoading || model.trimmedPoiId.isEmpty)
            }

            resultView
        }
        .padding()
    }

    private var knownPlaceIdChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CustomDataModel.knownPlaceIds, id: \.self) { knownPlaceId in
                    Button(knownPlaceId) {
                        model.poiId = knownPlaceId
                        load()
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .disabled(isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if model.loadFailed {
            Text("Could not load custom data")
                .foregroundStyle(.red)
        } else if let lookup = model.lookup {
            switch lookup {
            case .poiNotFound:
                Text("POI not found")
                    .foregroundStyle(.secondary)
            case .data(let data) where data.isEmpty:
                Text("No custom data for this POI")
                    .foregroundStyle(.secondary)
            case .data(let data):
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(value)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private func load() {
        guard !model.trimmedPoiId.isEmpty else { return }
        isLoading = true
        Task {
            await model.load()
            isLoading = false
        }
    }
}
