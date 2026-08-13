import SwiftUI

struct ContentView: View {
    var body: some View {
        List(Feature.allCases) { feature in
            NavigationLink(value: feature) {
                VStack(alignment: .leading) {
                    Text(feature.title)
                    Text(feature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("VisioOne Meet")
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
