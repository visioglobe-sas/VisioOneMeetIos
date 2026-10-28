import SwiftUI

/// Content of the panel shown when a POI is tapped on the map. Never opened
/// by a FAB: the screen presents it when `model.tappedPOI` goes non-nil,
/// reacting to the SDK's `poiclick` event. See docs/features/poi-click.md.
struct PoiClickPanel: View {
    @ObservedObject var model: PoiClickModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tapped POI")
                .font(.headline)

            if let poi = model.tappedPOI {
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let name = poi.name {
                            Text(verbatim: name)
                        } else {
                            Text("(no name)")
                        }
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    Text("ID: \(poi.id)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No POI selected")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
