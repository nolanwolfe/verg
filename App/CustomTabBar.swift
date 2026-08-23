import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab

    /// Ties the hovering capsule to whichever item is selected, so it slides
    /// between them instead of cross-fading in place.
    @Namespace private var hoverNamespace

    var body: some View {
        HStack(spacing: 0) {
            standardItem(tab: .verg, icon: nil, label: "Verg")
            standardItem(tab: .journal, icon: "book.closed.fill", label: "Journal")
            writeItem
            standardItem(tab: .library, icon: "books.vertical.fill", label: "Archive")
            standardItem(tab: .settings, icon: "gearshape.fill", label: "Settings")
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                // The 2.1 bar: blurred, then taken well down into black. The
                // bar itself is the dark, unbroken body spanning all five
                // tabs — the translucency people notice is the pane that
                // slides across it, not the bar. Lightening this to 12% made
                // the whole thing hazy and the slider stopped reading as
                // glass, because there was nothing dark for it to sit on.
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        // 72% black on paper would be a slab dropped on the
                        // page. Light mode keeps the same idea — a body dark
                        // enough for the pane to slide over — at a weight
                        // that still belongs on white.
                        .fill(Theme.Colors.adaptive(light: "1E1B1400", dark: "000000B8"))
                )
                // Specular highlight — a brighter strip of light along the
                // top edge, falling off fast.
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.adaptive(light: "FFFFFF00", dark: "FFFFFF33"),
                                    Theme.Colors.adaptive(light: "FFFFFF00", dark: "FFFFFF0A"),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.45)
                            )
                        )
                )
                // A faint counter-light along the bottom, so the pill reads
                // as a rounded body of glass rather than a lit top edge.
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Theme.Colors.adaptive(light: "FFFFFF00", dark: "FFFFFF0D")],
                                startPoint: UnitPoint(x: 0.5, y: 0.7),
                                endPoint: .bottom
                            )
                        )
                )
                // Edge border — glass rim catching light
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.adaptive(light: "17140E24", dark: "FFFFFF61"),
                                    Theme.Colors.adaptive(light: "17140E14", dark: "FFFFFF29"),
                                    Theme.Colors.adaptive(light: "17140E0A", dark: "FFFFFF14")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        // Elevation shadows — makes it hover
        .shadow(color: Theme.Colors.adaptive(light: "17140E1F", dark: "00000073"), radius: 24, x: 0, y: 10)
        .shadow(color: Theme.Colors.adaptive(light: "17140E14", dark: "0000002E"), radius: 4,  x: 0, y: 2)
        // Warm ambient glow under the pill (ties to candle aesthetic)
        .shadow(color: Color(hex: "FF7000").opacity(0.06), radius: 16, x: 0, y: 0)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    /// Every tab change ticks. Haptic always; the sound rides on the Sound
    /// setting, via AudioService.
    private func select(_ tab: ContentView.Tab) {
        guard tab != selectedTab else { return }
        AudioService.shared.playUITick()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            selectedTab = tab
        }
    }

    // MARK: - Hover
    /// The lozenge of brighter glass that rides under the selected tab —
    /// its own little pane sitting on the bar, catching light along the top
    /// edge the way the bar itself does. Only ever one exists; the namespace
    /// slides it between items rather than fading one out and another in.
    @ViewBuilder
    private func hover(for tab: ContentView.Tab) -> some View {
        if selectedTab == tab {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                // Clear, not tinted: the pane lifts the dark bar beneath it
                // rather than painting over it, which is what makes it read
                // as glass sliding across rather than a highlight fading in.
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.adaptive(light: "FFFFFFCC", dark: "FFFFFF38"),
                                    Theme.Colors.adaptive(light: "FFFFFF66", dark: "FFFFFF12"),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.adaptive(light: "17140E2E", dark: "FFFFFF6B"),
                                    Theme.Colors.adaptive(light: "17140E0F", dark: "FFFFFF1A")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
                // Warm underglow, so the lit tab belongs to the candle
                .shadow(color: Theme.Colors.flameOuter.opacity(0.18), radius: 8)
                .matchedGeometryEffect(id: "tabHover", in: hoverNamespace)
                .padding(.vertical, 4)
                .padding(.horizontal, 5)
        }
    }

    // MARK: - Standard Tab Item

    private func standardItem(tab: ContentView.Tab, icon: String?, label: String) -> some View {
        Button { select(tab) } label: {
            VStack(spacing: 4) {
                if tab == .verg {
                    CandleTabIcon(isSelected: selectedTab == .verg)
                        .frame(width: 22, height: 31)
                        .shadow(
                            color: Theme.Colors.flameOuter.opacity(selectedTab == .verg ? 0.5 : 0.25),
                            radius: 8
                        )
                        // Candle sits a touch taller — keep the row balanced
                        .offset(y: -4)
                } else {
                    Image(systemName: icon ?? "")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(selectedTab == tab
                            ? Theme.Colors.accent
                            : Theme.Colors.tertiaryText)
                        .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                }

                Text(label)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab
                        ? Theme.Colors.accent
                        : Theme.Colors.tertiaryText)
            }
            .offset(y: tab == .verg ? -3 : 0)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(hover(for: tab))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Write Tab

    private var writeItem: some View {
        Button { select(.write) } label: {
            VStack(spacing: 4) {
                WriteTabIcon(isSelected: selectedTab == .write)
                    .frame(width: 22, height: 22)
                    .scaleEffect(selectedTab == .write ? 1.05 : 1.0)

                Text("Write")
                    .font(.system(size: 10, weight: selectedTab == .write ? .semibold : .regular))
                    .foregroundColor(selectedTab == .write
                        ? Theme.Colors.accent
                        : Theme.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(hover(for: .write))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Write Tab Icon

struct WriteTabIcon: View {
    let isSelected: Bool

    private var color: Color {
        isSelected ? Theme.Colors.accent : Theme.Colors.tertiaryText
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Paper
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color, lineWidth: 1.1))

                VStack(spacing: 3.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.65))
                            .frame(height: 1.1)
                            .padding(.horizontal, 3)
                    }
                }
                .padding(.top, 5)
            }
            .frame(width: 15, height: 19)

            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .offset(x: 3, y: 3)
        }
    }
}

// MARK: - Candle Tab Icon (🕯️)

struct CandleTabIcon: View {
    let isSelected: Bool

    @State private var flameOffset: CGFloat = 0
    @State private var flameScale: CGFloat = 1.0
    @State private var innerOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.20

    var body: some View {
        VStack(spacing: 0) {
            // Flame
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.Colors.flameOuter.opacity(glowOpacity))
                        .frame(width: 18, height: 18)
                        .blendMode(.screen)
                }
                FlameShape()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color(hex: "FF4500"), Theme.Colors.flameInner]
                                : [Color(hex: "3A3A3A"), Color(hex: "2A2A2A")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 10, height: 14)
                    .scaleEffect(
                        x: isSelected ? flameScale : 1.0,
                        y: isSelected ? flameScale * 1.04 : 1.0,
                        anchor: .bottom
                    )
                    .offset(x: isSelected ? flameOffset : 0)

                if isSelected {
                    FlameShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFE000"), Color.white.opacity(0.9)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 5, height: 8)
                        .offset(x: innerOffset, y: 2)
                }
            }
            .frame(height: 15)

            // Wick
            Rectangle()
                .fill(isSelected ? Color(hex: "888888") : Color(hex: "3A3A3A"))
                .frame(width: 1.5, height: 3)

            // Wax body
            ZStack {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color(hex: "FFEEBB"), Color(hex: "E8D8A0")]
                                : [Color(hex: "484848"), Color(hex: "363636")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                // Highlight
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isSelected ? 0.4 : 0.12), Color.clear],
                            startPoint: .leading,
                            endPoint: .center
                        )
                    )
            }
            .frame(width: 14, height: 10)
        }
        .onAppear { if isSelected { startFlicker() } }
        .onChange(of: isSelected) { _, active in if active { startFlicker() } }
    }

    private func startFlicker() {
        withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) {
            flameOffset = 1.5; flameScale = 1.08
        }
        withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
            innerOffset = -1.0
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            glowOpacity = 0.65
        }
    }
}

// MARK: - Legacy stubs (referenced elsewhere, kept to avoid broken refs)
struct AnimatedFlameTabIcon: View {
    let isSelected: Bool
    var body: some View { EmptyView() }
}
struct VergFlameTabIcon: View {
    let isSelected: Bool
    var body: some View { EmptyView() }
}
