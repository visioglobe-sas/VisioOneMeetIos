import SwiftUI

struct ContentView: View {
    private var appDisplayName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "VisioOne Meet"
    }

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
        .safeAreaInset(edge: .top) {
            header
        }
        .navigationTitle("VisioOne Meet")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))

            Text("\(appDisplayName) by VisioGlobe")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
