// Enhanced Liquid Glass Extensions for Premium UI
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Enhanced Liquid Glass Effects
extension View {
    func premiumGlassEffect(
        style: Material = .regular,
        tint: Color? = nil,
        intensity: Double = 1.0
    ) -> some View {
        if #available(iOS 15.0, *) {
            return self
                .background(
                    ZStack {
                        // Base glass layer
                        Rectangle()
                            .fill(style)
                            .opacity(0.8)
                        
                        // Shimmer effect
                        if intensity > 0.5 {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .blendMode(.overlay)
                        }
                        
                        // Optional tint
                        if let tint = tint {
                            tint.opacity(0.1)
                                .blendMode(.softLight)
                        }
                    }
                )
                .compositingGroup()
        } else {
            return self
                .background(Color(.systemBackground).opacity(0.8))
        }
    }
    
    func interactiveGlass(
        pressedScale: Double = 0.98,
        pressedOpacity: Double = 0.8
    ) -> some View {
        self
            .scaleEffect(1.0)
            .opacity(1.0)
            .animation(.easeInOut(duration: 0.15), value: false)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    // Visual feedback
                }
            }
    }
    
    func morphingGlass(
        isExpanded: Bool,
        expandedHeight: CGFloat = 200
    ) -> some View {
        self
            .frame(height: isExpanded ? expandedHeight : nil)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: isExpanded ? 24 : 16,
                    style: .continuous
                )
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
    }
    
    func pulsingGlass(intensity: Double = 0.3) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(intensity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: intensity
                    )
            )
    }
}

// MARK: - Premium Glass Container
struct PremiumGlassContainer<Content: View>: View {
    let content: Content
    let style: ContainerStyle
    let interactions: InteractionStyle
    
    enum ContainerStyle {
        case elevated
        case recessed
        case floating
        case minimal
    }
    
    enum InteractionStyle {
        case none
        case hover
        case press
        case morphing
    }
    
    init(
        style: ContainerStyle = .elevated,
        interactions: InteractionStyle = .hover,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.interactions = interactions
    }
    
    var body: some View {
        content
            .modifier(GlassStyleModifier(style: style, interactions: interactions))
    }
}

struct GlassStyleModifier: ViewModifier {
    let style: PremiumGlassContainer<AnyView>.ContainerStyle
    let interactions: PremiumGlassContainer<AnyView>.InteractionStyle
    @State private var isPressed = false
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(backgroundForStyle)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(overlayForStyle)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: shadowOffset.x,
                y: shadowOffset.y
            )
            .scaleEffect(scaleForInteraction)
            .opacity(opacityForInteraction)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed.toggle()
                    }
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private var backgroundForStyle: some View {
        if #available(iOS 15.0, *) {
            switch style {
            case .elevated:
                return AnyView(
                    ZStack {
                        Material.regular
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                )
            case .recessed:
                return AnyView(
                    ZStack {
                        Material.thin
                        Color.black.opacity(0.05)
                    }
                )
            case .floating:
                return AnyView(
                    ZStack {
                        Material.ultraThick
                        RadialGradient(
                            colors: [.blue.opacity(0.1), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    }
                )
            case .minimal:
                return AnyView(Material.ultraThin)
            }
        } else {
            // iOS 14 fallback
            switch style {
            case .elevated:
                return AnyView(Color(.systemBackground).opacity(0.8))
            case .recessed:
                return AnyView(Color(.systemBackground).opacity(0.7))
            case .floating:
                return AnyView(Color(.systemBackground).opacity(0.9))
            case .minimal:
                return AnyView(Color(.systemBackground).opacity(0.6))
            }
        }
    }
    
    private var overlayForStyle: some View {
        switch style {
        case .elevated:
            return AnyView(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
        case .floating:
            return AnyView(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        default:
            return AnyView(EmptyView())
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .elevated: return 20
        case .recessed: return 12
        case .floating: return 24
        case .minimal: return 16
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated: return .black.opacity(0.15)
        case .floating: return .blue.opacity(0.2)
        default: return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated: return 20
        case .floating: return 30
        default: return 0
        }
    }
    
    private var shadowOffset: CGPoint {
        switch style {
        case .elevated: return CGPoint(x: 0, y: 10)
        case .floating: return CGPoint(x: 0, y: 15)
        default: return .zero
        }
    }
    
    private var scaleForInteraction: CGFloat {
        guard interactions != .none else { return 1.0 }
        
        switch interactions {
        case .press:
            return isPressed ? 0.96 : 1.0
        case .hover:
            return isHovered ? 1.02 : 1.0
        case .morphing:
            return isPressed ? 0.98 : (isHovered ? 1.01 : 1.0)
        default:
            return 1.0
        }
    }
    
    private var opacityForInteraction: Double {
        guard interactions != .none else { return 1.0 }
        
        switch interactions {
        case .press:
            return isPressed ? 0.8 : 1.0
        case .hover:
            return isHovered ? 0.9 : 1.0
        default:
            return 1.0
        }
    }
}

// MARK: - Advanced Visual Effects
struct ParticleEffect: View {
    let particleCount: Int
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var life: Double
        var maxLife: Double
        var size: CGFloat
        var color: Color
    }
    
    private func getCompatibleCyan() -> Color {
        if #available(iOS 15.0, *) {
            return .cyan
        } else {
            return Color(red: 0, green: 1, blue: 1)
        }
    }
    
    private func getCompatibleMint() -> Color {
        if #available(iOS 15.0, *) {
            return .mint
        } else {
            return Color(red: 0, green: 1, blue: 0.8)
        }
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            Canvas { context, size in
                for particle in particles {
                    let opacity = particle.life / particle.maxLife
                    let particleSize = particle.size * opacity
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: particle.position.x - particleSize / 2,
                            y: particle.position.y - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )),
                        with: .color(particle.color.opacity(opacity))
                    )
                }
            }
            .onAppear {
                generateParticles()
                startAnimation()
            }
        } else {
            // Fallback for iOS 14
            Rectangle()
                .fill(.clear)
                .onAppear {
                    generateParticles()
                    startAnimation()
                }
        }
    }
    
    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...400),
                    y: CGFloat.random(in: 0...800)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: -2...0)
                ),
                life: Double.random(in: 0.5...2.0),
                maxLife: 2.0,
                size: CGFloat.random(in: 2...6),
                color: [.blue, .purple, getCompatibleCyan(), getCompatibleMint()].randomElement() ?? .blue
            )
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for i in particles.indices {
            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y
            particles[i].life -= 0.016
            
            if particles[i].life <= 0 {
                particles[i] = Particle(
                    position: CGPoint(
                        x: CGFloat.random(in: 0...400),
                        y: 800
                    ),
                    velocity: CGPoint(
                        x: CGFloat.random(in: -1...1),
                        y: CGFloat.random(in: -2...0)
                    ),
                    life: Double.random(in: 0.5...2.0),
                    maxLife: 2.0,
                    size: CGFloat.random(in: 2...6),
                    color: [.blue, .purple, getCompatibleCyan(), getCompatibleMint()].randomElement() ?? .blue
                )
            }
        }
    }
}

// MARK: - Enhanced Button Styles
struct PremiumButtonStyle: ButtonStyle {
    let style: Style
    let size: Size
    
    enum Style {
        case primary
        case secondary
        case glass
        case gradient
    }
    
    enum Size {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large: return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .caption
            case .medium: return .subheadline
            case .large: return .headline
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .if(size == .small || size == .medium) { view in
                if #available(iOS 16.0, *) {
                    view.fontWeight(.semibold)
                } else {
                    view
                }
            }
            .padding(size.padding)
            .background(backgroundForStyle(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColorForStyle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
    
    @ViewBuilder
    private func backgroundForStyle(isPressed: Bool) -> some View {
        if #available(iOS 15.0, *) {
            switch style {
            case .primary:
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isPressed ? 0.8 : 1.0)
                
            case .secondary:
                Material.regular
                    .opacity(isPressed ? 0.5 : 0.8)
                
            case .glass:
                ZStack {
                    Material.ultraThin
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .opacity(isPressed ? 0.7 : 1.0)
                
            case .gradient:
                LinearGradient(
                    colors: [.purple, .blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isPressed ? 0.8 : 1.0)
            }
        } else {
            // iOS 14 fallback
            switch style {
            case .primary:
                Color.blue.opacity(isPressed ? 0.8 : 1.0)
            case .secondary:
                Color(.systemGray5).opacity(isPressed ? 0.5 : 0.8)
            case .glass:
                Color(.systemGray6).opacity(isPressed ? 0.7 : 1.0)
            case .gradient:
                Color.purple.opacity(isPressed ? 0.8 : 1.0)
            }
        }
    }
    
    private var foregroundColorForStyle: Color {
        switch style {
        case .primary, .gradient: return .white
        case .secondary, .glass: return .primary
        }
    }
}

extension ButtonStyle where Self == PremiumButtonStyle {
    static func premium(
        style: PremiumButtonStyle.Style = .primary,
        size: PremiumButtonStyle.Size = .medium
    ) -> PremiumButtonStyle {
        PremiumButtonStyle(style: style, size: size)
    }
}