// Essential Extensions and Fixes for Build
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI

// MARK: - Glass Effect Compatibility Extension
extension View {
    @available(iOS 15.0, *)
    @ViewBuilder
    func glassEffect(_ material: Material = .regular, in shape: AnyShape? = nil) -> some View {
        if #available(iOS 15.0, *) {
            self.background(
                material,
                in: shape ?? AnyShape(RoundedRectangle(cornerRadius: 0))
            )
        } else {
                // Fallback on earlier versions
        }
    }
    
    @ViewBuilder
    func glassEffect() -> some View {
        if #available(iOS 15.0, *) {
            self.background(.ultraThinMaterial)
        } else {
                // Fallback on earlier versions
        }
    }
}

// MARK: - AnyShape Helper
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Button Style Extension
@available(iOS 15.0, *)
extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle {
        GlassButtonStyle()
    }
}

@available(iOS 15.0, *)
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .easeInOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

// MARK: - Navigation Transition Extension (Fallback)
extension View {
    @ViewBuilder
    func navigationTransition<ID: Hashable>(_ transition: NavigationTransitionStyle, sourceID: ID, in namespace: Namespace.ID) -> some View {
        // Fallback implementation for older iOS versions
        self
    }
}

enum NavigationTransitionStyle {
    case zoom(sourceID: String, in: Namespace.ID)
}

// MARK: - Content Transition Extension (Fallback)
extension Text {
    @ViewBuilder
    func contentTransition(_ transition: ContentTransitionType) -> some View {
        // Fallback for older versions
        self
    }
}

struct ContentTransitionType {
    static func numericText(value: Double) -> ContentTransitionType {
        ContentTransitionType()
    }
}

// MARK: - Matched Transition Source Extension (Fallback)
extension View {
    @ViewBuilder
    func matchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        // Fallback implementation
        self
    }
}

// MARK: - Default Toolbar Item (Fallback)
struct DefaultToolbarItem: ToolbarContent {
    let kind: ToolbarItemKind
    let placement: ToolbarItemPlacement
    
    enum ToolbarItemKind {
        case search
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            EmptyView()
        }
    }
}

// MARK: - Toolbar Spacer (Fallback)
struct ToolbarSpacer {
    static let flexible = ToolbarSpacer()
}

// MARK: - Searchable Toolbar Behavior (Fallback)
extension View {
    @ViewBuilder
    func searchToolbarBehavior(_ behavior: SearchToolbarBehavior) -> some View {
        self
    }
}

enum SearchToolbarBehavior {
    case minimize
}

// MARK: - Scroll Clip Disabled (Fallback)
extension View {
    @ViewBuilder
    func scrollClipDisabled() -> some View {
        self
    }
}

// MARK: - Progress View Style (Fallback)
extension ProgressView {
    @ViewBuilder
    func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View {
        self
    }
}

// MARK: - Simple Data Models for Compilation
@available(iOS 15.0, *)
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    @available(iOS 15.0, *)
    var body: some View {
        if #available(iOS 15.0, *) {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
                // Fallback on earlier versions
        }
    }
}
