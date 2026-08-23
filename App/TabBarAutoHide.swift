import SwiftUI

/// Scroll-direction-driven tab bar visibility. Screens with scrolling
/// content publish their scroll offset through the environment; the
/// ContentView-owned tab bar reads it and hides/shows itself.
enum TabBarVisibility: Equatable {
    case visible
    case hidden
}

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<TabBarVisibility> = .constant(.visible)
}

extension EnvironmentValues {
    var tabBarVisibility: Binding<TabBarVisibility> {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

// MARK: - Scroll Direction Detection
/// Preference-key offset reader: reports the tracked content's Y position
/// in a named coordinate space; direction changes drive the tab bar.
struct ScrollDirectionDetector: ViewModifier {
    let coordinateSpace: String
    @Environment(\.tabBarVisibility) private var visibility
    @State private var lastMinY: CGFloat = 0
    @State private var minSeenY: CGFloat = .greatestFiniteMagnitude

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named(coordinateSpace)).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { minY in
                let delta = minY - lastMinY
                lastMinY = minY
                minSeenY = min(minSeenY, minY)

                guard abs(delta) > 1 else { return }
                if delta > 0 {
                    // Scrolling up (content moving down) — always show
                    if visibility.wrappedValue != .visible {
                        visibility.wrappedValue = .visible
                    }
                } else if minSeenY < -20 {
                    // Scrolling down and genuinely into the content — hide.
                    // The minSeenY guard keeps top-of-page bounce from hiding it.
                    if visibility.wrappedValue != .hidden {
                        visibility.wrappedValue = .hidden
                    }
                }
            }
            .onAppear {
                lastMinY = 0
                minSeenY = .greatestFiniteMagnitude
            }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Attach INSIDE a ScrollView that has `.coordinateSpace(name: matchingName)`.
    /// Reports scroll direction to the shared tab bar (hide on down, show on up).
    func trackScrollDirection(in coordinateSpace: String) -> some View {
        modifier(ScrollDirectionDetector(coordinateSpace: coordinateSpace))
    }
}
