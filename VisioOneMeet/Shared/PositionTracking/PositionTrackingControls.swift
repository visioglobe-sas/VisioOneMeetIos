import SwiftUI

/// The From/To POI id fields + accuracy slider + Start/Stop button shared by
/// the four tracking screens; each screen adds its own controls around it.
struct PositionTrackingControls: View {
    @ObservedObject var controller: PositionTrackingController

    var body: some View {
        Group {
            OriginDestinationFields(origin: $controller.originPlaceId, destination: $controller.destinationPlaceId)
                .disabled(controller.isSimulating)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accuracy radius: \(Int(controller.precisionCircleRadius)) m")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: $controller.precisionCircleRadius, in: 1...20, step: 1)
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(controller.isSimulating ? "Stop simulated position" : "Simulate position" as LocalizedStringKey) {
                controller.toggle()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(!controller.isSimulating && !controller.canStart)
        }
    }
}
