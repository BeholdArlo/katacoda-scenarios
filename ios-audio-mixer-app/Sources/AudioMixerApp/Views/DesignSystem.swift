import SwiftUI

// MARK: – Palette

enum DS {
    enum Color {
        static let void         = SwiftUI.Color(hex: 0x0D0014)
        static let deepViolet   = SwiftUI.Color(hex: 0x1F0040)
        static let burnOrange   = SwiftUI.Color(hex: 0xFF5500)
        static let magenta      = SwiftUI.Color(hex: 0xFF0066)
        static let acidYellow   = SwiftUI.Color(hex: 0xFFE500)
        static let teal         = SwiftUI.Color(hex: 0x00FFBA)
        static let cream        = SwiftUI.Color(hex: 0xFFF8E7)
        static let glassEdge    = SwiftUI.Color.white.opacity(0.12)

        static let bgGradient = LinearGradient(
            colors: [void, deepViolet],
            startPoint: .top,
            endPoint: .bottom
        )

        static let mixerGradient = LinearGradient(
            colors: [teal, acidYellow, burnOrange],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let panGradient = LinearGradient(
            colors: [burnOrange, cream, magenta],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: – Hex initialiser

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: – GlowEffect

struct GlowEffect: ViewModifier {
    let color: Color
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius * 0.4)
            .shadow(color: color.opacity(0.4), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 2)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: – GlassCard

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(DS.Color.deepViolet.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Color.glassEdge, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: – NeonText

struct NeonText: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
            .shadow(color: color.opacity(0.9), radius: 4)
            .shadow(color: color.opacity(0.4), radius: 10)
    }
}

extension View {
    func neon(_ color: Color) -> some View {
        modifier(NeonText(color: color))
    }
}

// MARK: – Shimmer

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear,                         location: phase - 0.3),
                        .init(color: .white.opacity(0.15),           location: phase),
                        .init(color: .clear,                         location: phase + 0.3),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: – GlowingDot (page indicator)

struct GlowingDot: View {
    let active: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(active ? color : color.opacity(0.3))
            .frame(width: active ? 10 : 6, height: active ? 10 : 6)
            .glow(active ? color : .clear, radius: active ? 6 : 0)
            .animation(.spring(response: 0.3), value: active)
    }
}

// MARK: – CustomGradientSlider

struct CustomGradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let gradient: LinearGradient
    let thumbColor: Color
    var onEditingChanged: (Bool) -> Void = { _ in }

    private let trackHeight: CGFloat = 6
    private let thumbSize:   CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let usable = geo.size.width - thumbSize
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = thumbSize / 2 + fraction * usable

            ZStack(alignment: .leading) {
                // Full track background
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: trackHeight)

                // Filled portion
                Capsule()
                    .fill(gradient)
                    .frame(width: thumbX, height: trackHeight)
                    .glow(thumbColor.opacity(0.6), radius: 4)

                // Thumb
                Circle()
                    .fill(thumbColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .glow(thumbColor, radius: 8)
                    .offset(x: thumbX - thumbSize / 2)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onEditingChanged(true)
                        let raw = Double((drag.location.x - thumbSize / 2) / usable)
                        value = (range.lowerBound + raw * (range.upperBound - range.lowerBound))
                            .clamped(to: range)
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
        }
        .frame(height: thumbSize)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
