import SwiftUI

struct OccupancySimulatedPanel: View {
    @ObservedObject var model: OccupancySimulatedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PoiIdField("Place ID", text: $model.placeId)
                .disabled(model.isSimulating)

            Button {
                model.toggle()
            } label: {
                Text(model.isSimulating ? "Stop occupancy simulation" : "Simulate occupancy" as LocalizedStringKey)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isSimulating && !model.canStart)
        }
        .padding()
    }
}
