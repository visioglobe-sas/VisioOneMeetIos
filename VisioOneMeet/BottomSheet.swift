import SwiftUI

private let peekHeight: CGFloat = 44
private let expandedHeight: CGFloat = 240
private let dragToggleThreshold: CGFloat = 60

struct BottomSheet<Content: View>: View {
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var height: CGFloat {
        let base = isExpanded ? expandedHeight : peekHeight
        return min(expandedHeight, max(peekHeight, base - dragOffset))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.vertical, 8)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            content
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)

            Spacer(minLength: 0)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .shadow(radius: 8, y: -2)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    dragOffset = 0
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if isExpanded {
                            isExpanded = value.translation.height < dragToggleThreshold
                        } else {
                            isExpanded = value.translation.height < -dragToggleThreshold
                        }
                    }
                }
        )
    }
}
