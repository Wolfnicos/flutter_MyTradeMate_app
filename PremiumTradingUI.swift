// Copyright 2025 MyTradeMate Premium UI
// Premium Trading Interface with Liquid Glass Design
// Optimized for iOS 15+ with latest SwiftUI features

import SwiftUI
import Charts

// MARK: - Data Models
struct AIInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let confidence: Double
}

struct WatchlistItem: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
}

struct PortfolioItem: Identifiable {
    let id = UUID()
    let symbol: String
    let shares: Int
    let value: Double
    let percentage: Double
    let color: Color
}

struct StockDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

enum TimeFrame: String, CaseIterable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case max = "ALL"
}

// MARK: - Data Generators
struct StockDataGenerator {
    static func generateSampleData() -> [StockDataPoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        return (0..<30).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: startDate)!
            let price = 170.0 + Double.random(in: -10...10)
            return StockDataPoint(date: date, price: price)
        }
    }
}

struct WatchlistDataGenerator {
    static func generateWatchlist() -> [WatchlistItem] {
        [
            WatchlistItem(symbol: "AAPL", name: "Apple Inc.", price: 174.32, change: 1.43),
            WatchlistItem(symbol: "TSLA", name: "Tesla Inc.", price: 251.89, change: -0.87),
            WatchlistItem(symbol: "MSFT", name: "Microsoft Corp.", price: 378.45, change: 2.14),
            WatchlistItem(symbol: "GOOGL", name: "Alphabet Inc.", price: 142.56, change: 0.92),
            WatchlistItem(symbol: "AMZN", name: "Amazon.com Inc.", price: 143.21, change: -1.23),
            WatchlistItem(symbol: "META", name: "Meta Platforms", price: 326.78, change: 3.45)
        ]
    }
}

struct PortfolioDataGenerator {
    static func generatePortfolio() -> [PortfolioItem] {
        [
            PortfolioItem(symbol: "AAPL", shares: 25, value: 4358.0, percentage: 34.6, color: .blue),
            PortfolioItem(symbol: "TSLA", shares: 5, value: 1259.45, percentage: 10.0, color: .red),
            PortfolioItem(symbol: "MSFT", shares: 8, value: 3027.60, percentage: 24.1, color: .green),
            PortfolioItem(symbol: "GOOGL", shares: 15, value: 2138.40, percentage: 17.0, color: .orange),
            PortfolioItem(symbol: "AMZN", shares: 10, value: 1432.10, percentage: 11.4, color: .purple),
            PortfolioItem(symbol: "META", shares: 1, value: 326.78, percentage: 2.6, color: .cyan)
        ]
    }
}

// MARK: - Notification System
struct TradingNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let action: NotificationAction?
    let timestamp: Date
    let duration: TimeInterval
    
    enum NotificationType {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    struct NotificationAction {
        let title: String
        let action: () -> Void
    }
    
    init(type: NotificationType, title: String, message: String, action: NotificationAction? = nil, duration: TimeInterval = 4.0) {
        self.type = type
        self.title = title
        self.message = message
        self.action = action
        self.timestamp = Date()
        self.duration = duration
    }
}

class PremiumNotificationManager: ObservableObject {
    static let shared = PremiumNotificationManager()
    @Published var notifications: [PremiumTradingUI.TradingNotification] = []
    
    private init() {}
    
    func addNotification(_ notification: PremiumTradingUI.TradingNotification) {
        withAnimation(.spring()) {
            notifications.append(notification)
        }
        
        // Auto-remove notification after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
            self.removeNotification(notification)
        }
    }
    
    func removeNotification(_ notification: PremiumTradingUI.TradingNotification) {
        withAnimation(.spring()) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
}

// MARK: - Missing UI Components
struct FloatingNotificationOverlay: View {
    @StateObject private var notificationManager = PremiumNotificationManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                ForEach(notificationManager.notifications) { notification in
                    NotificationCard(notification: notification)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

struct NotificationCard: View {
    let notification: PremiumTradingUI.TradingNotification
    @StateObject private var notificationManager = PremiumNotificationManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.iconName)
                .font(.title3)
                .foregroundStyle(notification.type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let action = notification.action {
                Button(action.title, action: action.action)
                    .buttonStyle(.premium(style: .glass, size: .small))
            }
            
            Button(action: { notificationManager.removeNotification(notification) }) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(Material.thick)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

struct PremiumAlertCenter: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Text("Alert Center - Premium alerts and notifications will be displayed here.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Alert Center")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Missing Component Definitions
// These provide compatibility for the premium components referenced in the UI

struct PremiumGlassContainer<Content: View>: View {
    let style: ContainerStyle
    let interactions: InteractionStyle
    let content: Content
    
    enum ContainerStyle {
        case elevated, recessed, floating, minimal
    }
    
    enum InteractionStyle {
        case morphing, hover
    }
    
    init(
        style: ContainerStyle = .elevated,
        interactions: InteractionStyle = .morphing,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.interactions = interactions
        self.content = content()
    }
    
    var body: some View {
        content
            .compatibleMaterial(materialForStyle)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadiusForStyle, style: .continuous))
            .shadow(
                color: shadowColorForStyle,
                radius: shadowRadiusForStyle,
                y: shadowOffsetForStyle
            )
    }
    
    private var materialForStyle: CompatibleMaterial.Style {
        switch style {
        case .elevated: return .regular
        case .recessed: return .thin
        case .floating: return .thick
        case .minimal: return .ultraThin
        }
    }
    
    private var cornerRadiusForStyle: CGFloat {
        switch style {
        case .elevated: return 20
        case .recessed: return 12
        case .floating: return 24
        case .minimal: return 16
        }
    }
    
    private var shadowColorForStyle: Color {
        switch style {
        case .elevated: return .black.opacity(0.1)
        case .floating: return .blue.opacity(0.1)
        default: return .clear
        }
    }
    
    private var shadowRadiusForStyle: CGFloat {
        switch style {
        case .elevated: return 10
        case .floating: return 15
        default: return 0
        }
    }
    
    private var shadowOffsetForStyle: CGFloat {
        switch style {
        case .elevated: return 5
        case .floating: return 8
        default: return 0
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    let style: Style
    let size: Size
    
    enum Style {
        case primary, secondary, glass, gradient
    }
    
    enum Size {
        case small, medium, large
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(fontForSize)
            .fontWeight(.semibold)
            .padding(paddingForSize)
            .background(backgroundForStyle)
            .foregroundColor(foregroundColorForStyle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var paddingForSize: EdgeInsets {
        switch size {
        case .small: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .medium: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        }
    }
    
    private var fontForSize: Font {
        switch size {
        case .small: return .caption
        case .medium: return .subheadline
        case .large: return .headline
        }
    }
    
    @ViewBuilder
    private var backgroundForStyle: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [.blue, .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            CompatibleMaterial(style: .regular)
        case .glass:
            CompatibleMaterial(style: .ultraThin)
        case .gradient:
            LinearGradient(
                colors: [.purple, .blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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

// MARK: - Compatible Material
struct CompatibleMaterial: View {
    let style: Style
    
    enum Style {
        case ultraThin, thin, regular, thick
    }
    
    var body: some View {
        switch style {
        case .ultraThin:
            if #available(iOS 15.0, *) {
                Material.ultraThin
            } else {
                Color.primary.opacity(0.05)
            }
        case .thin:
            if #available(iOS 15.0, *) {
                Material.thin
            } else {
                Color.primary.opacity(0.1)
            }
        case .regular:
            if #available(iOS 15.0, *) {
                Material.regular
            } else {
                Color.primary.opacity(0.15)
            }
        case .thick:
            if #available(iOS 15.0, *) {
                Material.thick
            } else {
                Color.primary.opacity(0.2)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleMaterial(_ style: CompatibleMaterial.Style) -> some View {
        self.background(CompatibleMaterial(style: style))
    }
    
    @ViewBuilder
    func morphingGlass(isExpanded: Bool, expandedHeight: CGFloat) -> some View {
        self.frame(height: isExpanded ? expandedHeight : nil)
            .clipped()
    }
}

// MARK: - Particle Effect (Simplified)
struct ParticleEffect: View {
    let particleCount: Int
    
    var body: some View {
        // Simplified particle effect - just some animated circles
        ZStack {
            ForEach(0..<min(particleCount, 10), id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: CGFloat.random(in: 2...8))
                    .position(
                        x: CGFloat.random(in: 0...400),
                        y: CGFloat.random(in: 0...800)
                    )
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 2...5))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: UUID()
                    )
            }
        }
        .onAppear {
            // Trigger animation
        }
    }
}

// MARK: - Refreshable ScrollView (Simplified)
struct RefreshableScrollView<Content: View>: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    let content: Content
    
    init(
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .refreshable {
                    isRefreshing = true
                    await onRefresh()
                }
        }
    }
}

// MARK: - Premium Trading View (Enhanced)
struct PremiumTradingView: View {
    @State private var selectedStock = "AAPL"
    @State private var searchText = ""
    @State private var isPresentingDetails = false
    @State private var isPresentingAlerts = false
    @State private var selectedTimeframe: TimeFrame = .day
    @State private var isRefreshing = false
    @State private var showingPortfolioRebalance = false
    @Namespace private var namespace
    @Environment(\.widgetRenderingMode) var renderingMode
    @StateObject private var notificationManager = PremiumNotificationManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with particles
                ParticleEffect(particleCount: 15)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    RefreshableScrollView(isRefreshing: $isRefreshing, onRefresh: performRefresh) {
                        LazyVStack(spacing: 20) {
                            // Enhanced Premium Header with AI Insights
                            EnhancedPremiumHeader()
                                .padding(.horizontal)
                            
                            // Live Market Status Bar
                            LiveMarketStatusBar()
                                .padding(.horizontal)
                            
                            // AI-Powered Insights with Enhanced Glass Effect
                            EnhancedAIInsightsContainer()
                                .padding(.horizontal)
                            
                            // Interactive 3D Chart with Advanced Features
                            Advanced3DChartCard(selectedStock: $selectedStock, 
                                              timeframe: $selectedTimeframe)
                                .padding(.horizontal)
                            
                            // Real-time Options Chain (New Feature)
                            OptionsChainContainer()
                                .padding(.horizontal)
                            
                            // Enhanced Watchlist with Heatmap
                            EnhancedWatchlistContainer()
                                .padding(.horizontal)
                            
                            // Advanced Portfolio Analytics
                            AdvancedPortfolioCard(showingRebalance: $showingPortfolioRebalance)
                                .padding(.horizontal)
                            
                            // Risk Management Dashboard
                            RiskManagementCard()
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
                
                // Floating notification overlay
                FloatingNotificationOverlay()
                    .allowsHitTesting(false)
            }
            .navigationTitle("MyTradeMate Pro")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search stocks, crypto, forex...")
            .searchToolbarBehavior(.minimize)
            .toolbar(id: "premium-toolbar") {
                EnhancedPremiumToolbarContent(
                    selectedStock: $selectedStock,
                    isPresentingDetails: $isPresentingDetails,
                    isPresentingAlerts: $isPresentingAlerts,
                    namespace: namespace
                )
            }
            .sheet(isPresented: $isPresentingDetails) {
                EnhancedStockDetailsSheet(stock: selectedStock)
                    .navigationTransition(.zoom(sourceID: "details-button", in: namespace))
            }
            .sheet(isPresented: $isPresentingAlerts) {
                PremiumAlertCenter()
                    .navigationTransition(.zoom(sourceID: "alerts-button", in: namespace))
            }
            .sheet(isPresented: $showingPortfolioRebalance) {
                PortfolioRebalanceSheet()
            }
            .onAppear {
                setupInitialData()
            }
        }
    }
    
    private func performRefresh() async {
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isRefreshing = false
        
        // Add a success notification
        notificationManager.addNotification(
            PremiumTradingUI.TradingNotification(
                type: .success,
                title: "Data Updated",
                message: "Market data refreshed successfully",
                action: nil,
                duration: 3.0
            )
        )
    }
    
    private func setupInitialData() {
        // Add welcome notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            notificationManager.addNotification(
                PremiumTradingUI.TradingNotification(
                    type: .info,
                    title: "Welcome Back!",
                    message: "Market opened 2 hours ago. Check your alerts.",
                    action: PremiumTradingUI.TradingNotification.NotificationAction(
                        title: "View Alerts"
                    ) {
                        isPresentingAlerts = true
                    },
                    duration: 5.0
                )
            )
        }
    }
}

// MARK: - Enhanced Premium Header Card
struct EnhancedPremiumHeader: View {
    @State private var totalBalance: Double = 125847.32
    @State private var dayChange: Double = 2347.18
    @State private var dayChangePercent: Double = 1.87
    @State private var animateBalance = false
    @State private var showingDetails = false
    
    var body: some View {
        PremiumGlassContainer(style: .floating, interactions: .morphing) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portfolio Value")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("$")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Text("\(totalBalance, specifier: "%.2f")")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText(value: totalBalance))
                                .animation(.spring(duration: 0.8), value: animateBalance)
                        }
                        
                        // Performance indicators
                        HStack(spacing: 12) {
                            PerformanceIndicator(
                                title: "Today",
                                value: dayChange,
                                percentage: dayChangePercent,
                                isPositive: dayChange >= 0
                            )
                            
                            PerformanceIndicator(
                                title: "This Week",
                                value: 1247.32,
                                percentage: 0.99,
                                isPositive: true
                            )
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Quick actions
                        VStack(spacing: 8) {
                            Button(action: {}) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.premium(style: .glass, size: .small))
                            
                            Button(action: {}) {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.premium(style: .glass, size: .small))
                        }
                    }
                }
                
                // AI-powered portfolio health score
                PortfolioHealthScore(score: 0.84)
                
                // Mini performance chart
                MiniPerformanceChart()
                    .frame(height: 60)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                animateBalance = true
            }
        }
        .onTapGesture {
            withAnimation(.spring()) {
                showingDetails.toggle()
            }
        }
        .morphingGlass(isExpanded: showingDetails, expandedHeight: 300)
    }
}

// MARK: - Performance Indicator
struct PerformanceIndicator: View {
    let title: String
    let value: Double
    let percentage: Double
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                
                Text("$\(abs(value), specifier: "%.0f")")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("(\(abs(percentage), specifier: "%.1f")%)")
                    .font(.caption2)
            }
            .foregroundStyle(isPositive ? .green : .red)
        }
        .padding(8)
        .background(
            (isPositive ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

// MARK: - Portfolio Health Score
struct PortfolioHealthScore: View {
    let score: Double
    @State private var animatedScore: Double = 0
    
    var healthColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        case 0.4..<0.6: return .yellow
        default: return .red
        }
    }
    
    var healthText: String {
        switch score {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Needs Attention"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(healthText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(healthColor)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(healthColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: animatedScore)
                    .stroke(
                        AngularGradient(
                            colors: [healthColor.opacity(0.5), healthColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score * 100))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(healthColor)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedScore = score
            }
        }
    }
}

// MARK: - Mini Performance Chart
struct MiniPerformanceChart: View {
    @State private var chartData = generateMiniChartData()
    
    var body: some View {
        Chart {
            ForEach(Array(chartData.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartBackground { proxy in
            Rectangle()
                .fill(.clear)
        }
    }
    
    static func generateMiniChartData() -> [Double] {
        (0..<20).map { _ in Double.random(in: 0.3...0.8) }
    }
}

// MARK: - Live Market Status Bar
struct LiveMarketStatusBar: View {
    @State private var isMarketOpen = true
    @State private var timeUntilClose = "2h 15m"
    @State private var pulseAnimation = false
    
    var body: some View {
        PremiumGlassContainer(style: .minimal) {
            HStack {
                // Market status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isMarketOpen ? .green : .red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: pulseAnimation)
                    
                    Text(isMarketOpen ? "Market Open" : "Market Closed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isMarketOpen {
                        Text("• \(timeUntilClose) to close")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Live market indicators
                HStack(spacing: 16) {
                    MarketIndicator(symbol: "SPY", change: 0.87, color: .green)
                    MarketIndicator(symbol: "QQQ", change: -0.23, color: .red)
                    MarketIndicator(symbol: "VIX", change: -2.45, color: .green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

struct MarketIndicator: View {
    let symbol: String
    let change: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("\(change > 0 ? "+" : "")\(change, specifier: "%.2f")%")
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Missing Component Implementations
struct EnhancedAIInsightsContainer: View {
    var body: some View {
        AIInsightsContainer()
    }
}


struct Advanced3DChartCard: View {
    @Binding var selectedStock: String
    @Binding var timeframe: TimeFrame
    
    var body: some View {
        StockChartCard(selectedStock: $selectedStock, timeframe: $timeframe)
    }
}

struct OptionsChainContainer: View {
    var body: some View {
        SimpleOptionsChain()
    }
}

struct TechnicalIndicatorsView: View {
    var body: some View {
        PremiumGlassContainer(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Technical Indicators")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    TechnicalIndicatorCard(name: "RSI", value: "67.5", signal: "Overbought", color: .orange)
                    TechnicalIndicatorCard(name: "MACD", value: "2.45", signal: "Bullish", color: .green)
                    TechnicalIndicatorCard(name: "BB %B", value: "0.78", signal: "Near Upper", color: .red)
                    TechnicalIndicatorCard(name: "Stoch", value: "82.1", signal: "Overbought", color: .orange)
                }
            }
            .padding(20)
        }
    }
}

struct TechnicalIndicatorCard: View {
    let name: String
    let value: String
    let signal: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(signal)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SimpleOptionsChain: View {
    @State private var selectedExpiry = "Dec 15, 2023"
    
    var body: some View {
        PremiumGlassContainer(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Options Chain")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(selectedExpiry)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .compatibleMaterial(.ultraThin)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Simplified options display
                VStack(spacing: 8) {
                    HStack {
                        Text("Calls")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                        
                        Text("Strike")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 60)
                        
                        Text("Puts")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                    
                    ForEach([165.0, 170.0, 175.0, 180.0, 185.0], id: \.self) { strike in
                        HStack {
                            Text("$\(Double.random(in: 0.5...15.0), specifier: "%.2f")")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                            
                            Text("$\(Int(strike))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 60)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(strike == 175 ? Color.blue.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("$\(Double.random(in: 0.5...15.0), specifier: "%.2f")")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - AI Insights Container
struct AIInsightsContainer: View {
    @State private var insights = [
        AIInsight(icon: "brain.head.profile", title: "AI Analysis", 
                 description: "Strong buy signal detected for TSLA", confidence: 0.87),
        AIInsight(icon: "chart.line.uptrend.xyaxis", title: "Market Trend", 
                 description: "Tech sector showing bullish momentum", confidence: 0.73),
        AIInsight(icon: "bell.badge", title: "Alert", 
                 description: "AAPL approaching resistance level", confidence: 0.91)
    ]
    
    var body: some View {
        PremiumGlassContainer(style: .floating, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("AI-Powered Insights", systemImage: "sparkles")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("See All") { }
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .compatibleMaterial(.ultraThin)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Confidence indicator
                HStack {
                    Text("Confidence:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    ProgressView(value: insight.confidence)
                        .frame(width: 60)
                        .scaleEffect(0.8)
                }
            }
            
            Spacer()
            
            Text("\(Int(insight.confidence * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(confidenceColor(insight.confidence))
        }
        .padding(12)
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - Stock Chart Card
struct StockChartCard: View {
    @Binding var selectedStock: String
    @Binding var timeframe: TimeFrame
    @State private var chartData = StockDataGenerator.generateSampleData()
    
    var body: some View {
        PremiumGlassContainer(style: .elevated, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(selectedStock)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Apple Inc.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    TimeframeSelector(selectedTimeframe: $timeframe)
                }
                
                // Premium Chart
                Chart {
                    ForEach(chartData) { data in
                        LineMark(
                            x: .value("Time", data.date),
                            y: .value("Price", data.price)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Time", data.date),
                            y: .value("Price", data.price)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 200)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                
                // Current price and change
                HStack {
                    Text("$174.32")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                        Text("+2.45 (1.43%)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    
                    Spacer()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Timeframe Selector
struct TimeframeSelector: View {
    @Binding var selectedTimeframe: TimeFrame
    
    var body: some View {
        PremiumGlassContainer(style: .minimal) {
            HStack(spacing: 8) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Button(timeframe.rawValue) {
                        selectedTimeframe = timeframe
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .compatibleMaterial(.ultraThin)
                    .clipShape(.capsule)
                    .foregroundStyle(selectedTimeframe == timeframe ? .blue : .primary)
                }
            }
        }
    }
}

// MARK: - Watchlist Container
struct WatchlistContainer: View {
    @State private var watchlistItems = WatchlistDataGenerator.generateWatchlist()
    
    var body: some View {
        PremiumGlassContainer(style: .floating, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Watchlist", systemImage: "list.bullet")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Edit") { }
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(watchlistItems) { item in
                        WatchlistRow(item: item)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct WatchlistRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(item.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 2) {
                    Image(systemName: item.change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    
                    Text("\(item.change >= 0 ? "+" : "")\(item.change, specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundStyle(item.change >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
        .compatibleMaterial(.regular)
    }
}

// MARK: - Advanced Portfolio Card
struct AdvancedPortfolioCard: View {
    @Binding var showingRebalance: Bool
    @State private var portfolioItems = PortfolioDataGenerator.generatePortfolio()
    @State private var selectedMetric: PortfolioMetric = .allocation
    
    enum PortfolioMetric: String, CaseIterable {
        case allocation = "Allocation"
        case performance = "Performance"
        case risk = "Risk"
        case diversification = "Diversity"
        
        var iconName: String {
            switch self {
            case .allocation: return "chart.pie.fill"
            case .performance: return "chart.line.uptrend.xyaxis"
            case .risk: return "exclamationmark.shield.fill"
            case .diversification: return "arrow.triangle.branch"
            }
        }
    }
    
    var body: some View {
        PremiumGlassContainer(style: .elevated, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header with metric selector
                HStack {
                    Label("Portfolio Analytics", systemImage: "briefcase.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                    
                    Spacer()
                    
                    // Metric selector
                    HStack(spacing: 8) {
                        ForEach(PortfolioMetric.allCases, id: \.self) { metric in
                            Button(action: { selectedMetric = metric }) {
                                VStack(spacing: 4) {
                                    Image(systemName: metric.iconName)
                                        .font(.caption)
                                    Text(metric.rawValue)
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.premium(
                                style: selectedMetric == metric ? .primary : .glass,
                                size: .small
                            ))
                        }
                    }
                }
                
                // Portfolio overview stats
                PortfolioOverviewStats()
                
                // Dynamic content based on selected metric
                Group {
                    switch selectedMetric {
                    case .allocation:
                        PortfolioAllocationView(items: portfolioItems)
                    case .performance:
                        PortfolioPerformanceView(items: portfolioItems)
                    case .risk:
                        PortfolioRiskView(items: portfolioItems)
                    case .diversification:
                        PortfolioDiversificationView(items: portfolioItems)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedMetric)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Rebalance Portfolio") {
                        showingRebalance = true
                    }
                    .buttonStyle(.premium(style: .primary, size: .medium))
                    
                    Button("Analyze Risk") { }
                        .buttonStyle(.premium(style: .secondary, size: .medium))
                    
                    Button("Export") { }
                        .buttonStyle(.premium(style: .glass, size: .medium))
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Portfolio Overview Stats
struct PortfolioOverviewStats: View {
    var body: some View {
        HStack(spacing: 16) {
            PortfolioStatCard(
                title: "Total Value",
                value: "$125,847",
                change: "+2.3%",
                isPositive: true,
                icon: "dollarsign.circle.fill"
            )
            
            PortfolioStatCard(
                title: "Today's P&L",
                value: "+$2,347",
                change: "+1.9%",
                isPositive: true,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            PortfolioStatCard(
                title: "Risk Score",
                value: "7.2/10",
                change: "Moderate",
                isPositive: false,
                icon: "shield.checkered"
            )
        }
    }
}

struct PortfolioStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isPositive ? .green : .orange)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(change)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isPositive ? .green : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            (isPositive ? Color.green : Color.orange).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - Portfolio Views
struct PortfolioAllocationView: View {
    let items: [PortfolioItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Allocation")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Pie chart representation
            HStack {
                Chart {
                    ForEach(items) { item in
                        SectorMark(
                            angle: .value("Percentage", item.percentage),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color)
                        .opacity(0.8)
                    }
                }
                .frame(width: 120, height: 120)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items.prefix(4)) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            
                            Text(item.symbol)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(item.percentage, specifier: "%.1f")%")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct PortfolioPerformanceView: View {
    let items: [PortfolioItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricCard(title: "YTD Return", value: "+18.4%", color: .green)
                PerformanceMetricCard(title: "Sharpe Ratio", value: "1.23", color: .blue)
                PerformanceMetricCard(title: "Max Drawdown", value: "-5.2%", color: .red)
                PerformanceMetricCard(title: "Beta", value: "0.89", color: .orange)
            }
            
            // Performance chart
            Text("6 Month Performance")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Chart {
                ForEach(generatePerformanceData(), id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Return", point.returnValue)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .frame(height: 80)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
    
    func generatePerformanceData() -> [PerformancePoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -6, to: Date())!
        
        return (0..<30).map { index in
            let date = calendar.date(byAdding: .day, value: index * 6, to: startDate)!
            let returnValue = Double.random(in: -0.05...0.25)
            return PerformancePoint(date: date, returnValue: returnValue)
        }
    }
}

struct PerformancePoint {
    let date: Date
    let returnValue: Double
}

struct PerformanceMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PortfolioRiskView: View {
    let items: [PortfolioItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Risk Analysis")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Risk meter
            VStack(spacing: 8) {
                HStack {
                    Text("Portfolio Risk Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("7.2/10 - Moderate")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                
                ProgressView(value: 0.72)
                    .progressViewStyle(CustomProgressViewStyle())
            }
            
            // Risk factors
            LazyVStack(spacing: 8) {
                RiskFactorRow(factor: "Concentration Risk", level: "High", description: "65% in top 2 holdings")
                RiskFactorRow(factor: "Sector Exposure", level: "Medium", description: "Tech sector dominance")
                RiskFactorRow(factor: "Volatility", level: "Low", description: "Below market average")
                RiskFactorRow(factor: "Correlation", level: "Medium", description: "Moderate diversification")
            }
        }
    }
}

struct RiskFactorRow: View {
    let factor: String
    let level: String
    let description: String
    
    var levelColor: Color {
        switch level.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(factor)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(level)
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(levelColor.opacity(0.2))
                .foregroundStyle(levelColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct PortfolioDiversificationView: View {
    let items: [PortfolioItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diversification Analysis")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Diversification score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diversification Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("6.5/10")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Text("Room for improvement")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(progress: 0.65, color: .orange)
                    .frame(width: 60, height: 60)
            }
            
            // Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                DiversificationTip(
                    icon: "plus.circle",
                    text: "Add international exposure",
                    color: .blue
                )
                
                DiversificationTip(
                    icon: "arrow.triangle.branch",
                    text: "Reduce concentration in tech",
                    color: .orange
                )
                
                DiversificationTip(
                    icon: "building.columns",
                    text: "Consider REITs or commodities",
                    color: .green
                )
            }
        }
    }
}

struct DiversificationTip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
            
            Spacer()
        }
        .padding(8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Risk Management Card
struct RiskManagementCard: View {
    @State private var selectedRiskMetric: RiskMetric = .valueAtRisk
    
    enum RiskMetric: String, CaseIterable {
        case valueAtRisk = "VaR"
        case sharpe = "Sharpe"
        case beta = "Beta"
        case stress = "Stress"
        
        var fullName: String {
            switch self {
            case .valueAtRisk: return "Value at Risk"
            case .sharpe: return "Sharpe Ratio"
            case .beta: return "Portfolio Beta"
            case .stress: return "Stress Testing"
            }
        }
    }
    
    var body: some View {
        PremiumGlassContainer(style: .recessed, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Risk Management", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    
                    Spacer()
                    
                    // Risk metric selector
                    Picker("Risk Metric", selection: $selectedRiskMetric) {
                        ForEach(RiskMetric.allCases, id: \.self) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Risk metric display
                RiskMetricDisplay(metric: selectedRiskMetric)
                
                // Risk alerts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Risk Alerts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    RiskAlert(
                        type: .warning,
                        title: "High Correlation Detected",
                        description: "AAPL and MSFT correlation above 0.8"
                    )
                    
                    RiskAlert(
                        type: .info,
                        title: "Position Size Alert",
                        description: "TSLA position exceeds 15% allocation limit"
                    )
                }
            }
            .padding(24)
        }
    }
}

struct RiskMetricDisplay: View {
    let metric: RiskManagementCard.RiskMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.fullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                switch metric {
                case .valueAtRisk:
                    Text("$3,247")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    
                    Text("95% confidence, 1-day horizon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                case .sharpe:
                    Text("1.23")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    
                    Text("Above market average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                case .beta:
                    Text("0.89")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    
                    Text("Less volatile than market")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                case .stress:
                    Text("-12.3%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Text("2008 financial crisis scenario")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Visual indicator
            RiskIndicatorChart(metric: metric)
                .frame(width: 80, height: 80)
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RiskIndicatorChart: View {
    let metric: RiskManagementCard.RiskMetric
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(colorForMetric, lineWidth: 8)
                .rotationEffect(.degrees(-90))
            
            Text(displayValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(colorForMetric)
        }
        .animation(.easeInOut(duration: 1), value: progressValue)
    }
    
    private var progressValue: Double {
        switch metric {
        case .valueAtRisk: return 0.65
        case .sharpe: return 0.82
        case .beta: return 0.45
        case .stress: return 0.38
        }
    }
    
    private var colorForMetric: Color {
        switch metric {
        case .valueAtRisk: return .red
        case .sharpe: return .green
        case .beta: return .blue
        case .stress: return .orange
        }
    }
    
    private var displayValue: String {
        switch metric {
        case .valueAtRisk: return "65%"
        case .sharpe: return "1.2"
        case .beta: return "0.89"
        case .stress: return "-12%"
        }
    }
}

struct RiskAlert: View {
    let type: AlertType
    let title: String
    let description: String
    
    enum AlertType {
        case warning, info, critical
        
        var color: Color {
            switch self {
            case .warning: return .orange
            case .info: return .blue
            case .critical: return .red
            }
        }
        
        var iconName: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.title3)
                .foregroundStyle(type.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Review") { }
                .buttonStyle(.premium(style: .glass, size: .small))
        }
        .padding(12)
        .background(type.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Custom Progress View Style
struct CustomProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.tertiary)
                .frame(height: 8)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.green, .orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: (configuration.fractionCompleted ?? 0) * 300, height: 8)
                .animation(.easeInOut, value: configuration.fractionCompleted)
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, lineWidth: 6)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

struct PortfolioRow: View {
    let item: PortfolioItem
    
    var body: some View {
        HStack {
            Circle()
                .fill(item.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(item.shares) shares")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(item.value, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(item.percentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Enhanced Premium Toolbar Content
struct EnhancedPremiumToolbarContent: ToolbarContent {
    @Binding var selectedStock: String
    @Binding var isPresentingDetails: Bool
    @Binding var isPresentingAlerts: Bool
    let namespace: Namespace.ID
    
    var body: some ToolbarContent {
        ToolbarItem(id: "notifications", placement: .navigationBarLeading) {
            Button(action: { isPresentingAlerts = true }) {
                ZStack {
                    Image(systemName: "bell.badge.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.title3)
                    
                    // Notification count badge
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
            .buttonStyle(.premium(style: .glass, size: .small))
            .matchedTransitionSource(id: "alerts-button", in: namespace)
        }
        
        ToolbarItem(id: "ai-assistant", placement: .navigationBarTrailing) {
            Button(action: {}) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
            }
            .buttonStyle(.premium(style: .gradient, size: .small))
        }
        
        ToolbarItem(id: "search", placement: .navigationBarTrailing) {
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
            }
            .buttonStyle(.premium(style: .glass, size: .small))
        }
        
        ToolbarItem(id: "details", placement: .navigationBarTrailing) {
            Button("Analysis") {
                isPresentingDetails = true
            }
            .buttonStyle(.premium(style: .primary, size: .small))
            .matchedTransitionSource(id: "details-button", in: namespace)
        }
        
        ToolbarItem(id: "more", placement: .navigationBarTrailing) {
            Menu {
                Button("Portfolio Rebalance", systemImage: "arrow.triangle.2.circlepath") { }
                Button("Risk Analysis", systemImage: "shield.checkered") { }
                Button("Tax Optimization", systemImage: "percent") { }
                Divider()
                Button("Export Data", systemImage: "square.and.arrow.up") { }
                Button("Settings", systemImage: "gear") { }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.premium(style: .glass, size: .small))
        }
    }
}

// MARK: - Enhanced Watchlist Container
struct EnhancedWatchlistContainer: View {
    @State private var watchlistItems = WatchlistDataGenerator.generateWatchlist()
    @State private var viewMode: ViewMode = .list
    @State private var sortBy: SortOption = .alphabetical
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case heatmap = "Heatmap"
        case grid = "Grid"
        
        var iconName: String {
            switch self {
            case .list: return "list.bullet"
            case .heatmap: return "square.grid.3x3.fill"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case alphabetical = "A-Z"
        case performance = "Performance"
        case volume = "Volume"
        case marketCap = "Market Cap"
    }
    
    var sortedItems: [WatchlistItem] {
        switch sortBy {
        case .alphabetical:
            return watchlistItems.sorted { $0.symbol < $1.symbol }
        case .performance:
            return watchlistItems.sorted { $0.change > $1.change }
        case .volume:
            return watchlistItems.shuffled() // Placeholder
        case .marketCap:
            return watchlistItems.sorted { $0.price > $1.price }
        }
    }
    
    var body: some View {
        PremiumGlassContainer(style: .floating, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header with controls
                HStack {
                    Label("Watchlist", systemImage: "list.star")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // View mode selector
                    HStack(spacing: 8) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Button(action: { viewMode = mode }) {
                                Image(systemName: mode.iconName)
                                    .font(.caption)
                            }
                            .buttonStyle(.premium(
                                style: viewMode == mode ? .primary : .glass,
                                size: .small
                            ))
                        }
                    }
                    
                    // Sort menu
                    Menu(sortBy.rawValue) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { sortBy = option }
                        }
                    }
                    .buttonStyle(.premium(style: .glass, size: .small))
                }
                
                // Content based on view mode
                Group {
                    switch viewMode {
                    case .list:
                        WatchlistListView(items: sortedItems)
                    case .heatmap:
                        WatchlistHeatmapView(items: sortedItems)
                    case .grid:
                        WatchlistGridView(items: sortedItems)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewMode)
            }
            .padding(24)
        }
    }
}

// MARK: - Watchlist Views
struct WatchlistListView: View {
    let items: [WatchlistItem]
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                EnhancedWatchlistRow(item: item)
            }
        }
    }
}

struct WatchlistHeatmapView: View {
    let items: [WatchlistItem]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(items) { item in
                WatchlistHeatmapCell(item: item)
            }
        }
    }
}

struct WatchlistGridView: View {
    let items: [WatchlistItem]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(items) { item in
                WatchlistGridCell(item: item)
            }
        }
    }
}

struct EnhancedWatchlistRow: View {
    let item: WatchlistItem
    @State private var isExpanded = false
    
    var body: some View {
        PremiumGlassContainer(style: .minimal, interactions: .hover) {
            VStack(spacing: 0) {
                HStack {
                    // Stock info
                    HStack(spacing: 12) {
                        // Logo placeholder
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(item.symbol.first ?? "?"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.symbol)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Price and change
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(item.price, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 4) {
                            Image(systemName: item.change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            
                            Text("\(item.change >= 0 ? "+" : "")\(item.change, specifier: "%.2f")%")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(item.change >= 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (item.change >= 0 ? Color.green : Color.red).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    
                    // Expand button
                    Button(action: { 
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(16)
                
                // Expanded content
                if isExpanded {
                    Divider()
                    
                    HStack {
                        MiniChart(data: generateMiniData())
                            .frame(height: 40)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Button("Trade") { }
                                .buttonStyle(.premium(style: .primary, size: .small))
                            
                            Button("Alert") { }
                                .buttonStyle(.premium(style: .glass, size: .small))
                        }
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .animation(.spring(response: 0.4), value: isExpanded)
    }
    
    private func generateMiniData() -> [Double] {
        (0..<10).map { _ in Double.random(in: 0.3...0.8) }
    }
}

struct WatchlistHeatmapCell: View {
    let item: WatchlistItem
    
    var heatmapColor: Color {
        let intensity = abs(item.change) / 5.0 // Normalize to 0-1 range
        return item.change >= 0 ? 
            Color.green.opacity(min(intensity, 1.0)) :
            Color.red.opacity(min(intensity, 1.0))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(item.symbol)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(item.change >= 0 ? .green : .red)
            
            Text("\(item.change >= 0 ? "+" : "")\(item.change, specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(heatmapColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct WatchlistGridCell: View {
    let item: WatchlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Image(systemName: item.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(item.change >= 0 ? .green : .red)
            }
            
            Text("$\(item.price, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("\(item.change >= 0 ? "+" : "")\(item.change, specifier: "%.2f")%")
                .font(.caption)
                .foregroundStyle(item.change >= 0 ? .green : .red)
        }
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Mini Chart Component
struct MiniChart: View {
    let data: [Double]
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Enhanced Stock Details Sheet
struct EnhancedStockDetailsSheet: View {
    let stock: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case technicals = "Technical"
        case fundamentals = "Fundamentals"
        case news = "News"
        case options = "Options"
        
        var iconName: String {
            switch self {
            case .overview: return "chart.bar.doc.horizontal"
            case .technicals: return "waveform.path.ecg"
            case .fundamentals: return "building.columns"
            case .news: return "newspaper"
            case .options: return "link"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                VStack(spacing: 8) {
                                    Image(systemName: tab.iconName)
                                        .font(.title3)
                                    
                                    Text(tab.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .buttonStyle(.premium(
                                style: selectedTab == tab ? .primary : .glass,
                                size: .medium
                            ))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                
                // Content based on selected tab
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            StockOverviewContent(stock: stock)
                        case .technicals:
                            StockTechnicalContent(stock: stock)
                        case .fundamentals:
                            StockFundamentalsContent(stock: stock)
                        case .news:
                            StockNewsContent(stock: stock)
                        case .options:
                            StockOptionsContent(stock: stock)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(stock)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.premium(style: .glass, size: .small))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add to Watchlist", systemImage: "plus") { }
                        Button("Set Price Alert", systemImage: "bell") { }
                        Button("Share Analysis", systemImage: "square.and.arrow.up") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.premium(style: .glass, size: .small))
                }
            }
        }
    }
}

// MARK: - Stock Content Views
struct StockOverviewContent: View {
    let stock: String
    
    var body: some View {
        LazyVStack(spacing: 20) {
            // Price and change
            PremiumGlassContainer(style: .elevated) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("$174.32")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            HStack {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                Text("+2.45 (1.43%)")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Buy") { }
                                .buttonStyle(.premium(style: .primary, size: .medium))
                            
                            Button("Sell") { }
                                .buttonStyle(.premium(style: .secondary, size: .medium))
                        }
                    }
                    
                    // Key stats
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        KeyStatCard(title: "Open", value: "$172.50")
                        KeyStatCard(title: "High", value: "$175.80")
                        KeyStatCard(title: "Low", value: "$171.20")
                        KeyStatCard(title: "Volume", value: "45.2M")
                        KeyStatCard(title: "Market Cap", value: "$2.8T")
                        KeyStatCard(title: "P/E Ratio", value: "28.5")
                    }
                }
                .padding(20)
            }
            
            // Chart
            Advanced3DChartCard(selectedStock: .constant(stock), timeframe: .constant(.day))
        }
    }
}

struct KeyStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StockTechnicalContent: View {
    let stock: String
    
    var body: some View {
        LazyVStack(spacing: 20) {
            // Technical indicators overview
            TechnicalIndicatorsView()
            
            // Support and resistance
            PremiumGlassContainer(style: .recessed) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Support & Resistance Levels")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        SupportResistanceLevel(type: "Strong Resistance", price: 178.50, distance: "+2.4%")
                        SupportResistanceLevel(type: "Resistance", price: 176.20, distance: "+1.1%")
                        SupportResistanceLevel(type: "Current Price", price: 174.32, distance: "0.0%", isCurrent: true)
                        SupportResistanceLevel(type: "Support", price: 172.10, distance: "-1.3%")
                        SupportResistanceLevel(type: "Strong Support", price: 169.80, distance: "-2.6%")
                    }
                }
                .padding(20)
            }
        }
    }
}

struct SupportResistanceLevel: View {
    let type: String
    let price: Double
    let distance: String
    let isCurrent: Bool
    
    init(type: String, price: Double, distance: String, isCurrent: Bool = false) {
        self.type = type
        self.price = price
        self.distance = distance
        self.isCurrent = isCurrent
    }
    
    var body: some View {
        HStack {
            Text(type)
                .font(.subheadline)
                .fontWeight(isCurrent ? .bold : .medium)
            
            Spacer()
            
            Text("$\(price, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(distance)
                .font(.caption)
                .foregroundStyle(isCurrent ? .blue : .secondary)
        }
        .padding(.vertical, 4)
        .background(
            isCurrent ? Color.blue.opacity(0.1) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StockFundamentalsContent: View {
    let stock: String
    
    var body: some View {
        LazyVStack(spacing: 20) {
            // Financial metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                FundamentalMetricCard(title: "P/E Ratio", value: "28.5", description: "Price to Earnings")
                FundamentalMetricCard(title: "EPS", value: "$6.12", description: "Earnings Per Share")
                FundamentalMetricCard(title: "Revenue", value: "$394.3B", description: "Annual Revenue")
                FundamentalMetricCard(title: "Dividend", value: "0.57%", description: "Dividend Yield")
                FundamentalMetricCard(title: "ROE", value: "26.4%", description: "Return on Equity")
                FundamentalMetricCard(title: "Debt/Equity", value: "1.73", description: "Debt to Equity Ratio")
            }
        }
    }
}

struct FundamentalMetricCard: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StockNewsContent: View {
    let stock: String
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5) { index in
                NewsArticleCard(
                    headline: "Apple Reports Strong Q4 Earnings with Record iPhone Sales",
                    summary: "Apple exceeded analysts' expectations with revenue of $94.9 billion, driven by strong iPhone 15 sales and services growth.",
                    source: "Reuters",
                    timeAgo: "\(index + 1)h ago",
                    sentiment: index % 3 == 0 ? .positive : (index % 3 == 1 ? .neutral : .negative)
                )
            }
        }
    }
}

struct NewsArticleCard: View {
    let headline: String
    let summary: String
    let source: String
    let timeAgo: String
    let sentiment: NewsSentiment
    
    enum NewsSentiment {
        case positive, negative, neutral
        
        var color: Color {
            switch self {
            case .positive: return .green
            case .negative: return .red
            case .neutral: return .blue
            }
        }
        
        var iconName: String {
            switch self {
            case .positive: return "arrow.up.circle.fill"
            case .negative: return "arrow.down.circle.fill"
            case .neutral: return "minus.circle.fill"
            }
        }
    }
    
    var body: some View {
        PremiumGlassContainer(style: .minimal, interactions: .hover) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(source)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: sentiment.iconName)
                            .font(.caption)
                            .foregroundStyle(sentiment.color)
                        
                        Text(timeAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(headline)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(16)
        }
    }
}

struct StockOptionsContent: View {
    let stock: String
    
    var body: some View {
        OptionsChainContainer()
    }
}

// MARK: - Portfolio Rebalance Sheet
struct PortfolioRebalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rebalanceStrategy: RebalanceStrategy = .equal
    @State private var currentAllocations = PortfolioDataGenerator.generatePortfolio()
    @State private var targetAllocations: [PortfolioItem] = []
    
    enum RebalanceStrategy: String, CaseIterable {
        case equal = "Equal Weight"
        case marketCap = "Market Cap"
        case riskParity = "Risk Parity"
        case custom = "Custom"
        
        var description: String {
            switch self {
            case .equal: return "Equal allocation across all holdings"
            case .marketCap: return "Weight by market capitalization"
            case .riskParity: return "Weight by risk contribution"
            case .custom: return "Set custom allocations"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Strategy selector
                    PremiumGlassContainer(style: .elevated) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Rebalancing Strategy")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(RebalanceStrategy.allCases, id: \.self) { strategy in
                                    Button(action: { rebalanceStrategy = strategy }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(strategy.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                Spacer()
                                                
                                                if rebalanceStrategy == strategy {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.green)
                                                }
                                            }
                                            
                                            Text(strategy.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(12)
                                        .background(
                                            rebalanceStrategy == strategy ? 
                                                Material.thick : Material.ultraThin
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                    }
                    
                    // Current vs Target allocations
                    PremiumGlassContainer(style: .floating) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Portfolio Comparison")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 20) {
                                // Current allocation
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Current")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    
                                    Chart {
                                        ForEach(currentAllocations) { item in
                                            SectorMark(
                                                angle: .value("Percentage", item.percentage),
                                                innerRadius: .ratio(0.6),
                                                angularInset: 2
                                            )
                                            .foregroundStyle(item.color.opacity(0.8))
                                        }
                                    }
                                    .frame(width: 120, height: 120)
                                }
                                
                                Spacer()
                                
                                // Target allocation
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Target")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    
                                    Chart {
                                        ForEach(generateTargetAllocations()) { item in
                                            SectorMark(
                                                angle: .value("Percentage", item.percentage),
                                                innerRadius: .ratio(0.6),
                                                angularInset: 2
                                            )
                                            .foregroundStyle(item.color.opacity(0.8))
                                        }
                                    }
                                    .frame(width: 120, height: 120)
                                }
                            }
                            
                            // Allocation details
                            VStack(spacing: 8) {
                                ForEach(currentAllocations) { current in
                                    let target = generateTargetAllocations().first { $0.symbol == current.symbol }
                                    AllocationComparisonRow(
                                        symbol: current.symbol,
                                        currentPercent: current.percentage,
                                        targetPercent: target?.percentage ?? current.percentage,
                                        color: current.color
                                    )
                                }
                            }
                        }
                        .padding(20)
                    }
                    
                    // Rebalancing impact
                    RebalanceImpactView()
                }
                .padding(20)
            }
            .navigationTitle("Portfolio Rebalance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.premium(style: .secondary, size: .small))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Execute Rebalance") {
                        // Execute rebalancing
                        dismiss()
                    }
                    .buttonStyle(.premium(style: .primary, size: .medium))
                }
            }
        }
    }
    
    private func generateTargetAllocations() -> [PortfolioItem] {
        switch rebalanceStrategy {
        case .equal:
            let equalPercent = 100.0 / Double(currentAllocations.count)
            return currentAllocations.map { item in
                PortfolioItem(
                    symbol: item.symbol,
                    shares: item.shares,
                    value: item.value,
                    percentage: equalPercent,
                    color: item.color
                )
            }
        case .marketCap:
            // Simplified market cap weighting
            return currentAllocations.enumerated().map { index, item in
                let weight = [40.0, 30.0, 20.0, 10.0][index % 4]
                return PortfolioItem(
                    symbol: item.symbol,
                    shares: item.shares,
                    value: item.value,
                    percentage: weight,
                    color: item.color
                )
            }
        case .riskParity:
            // Simplified risk parity
            return currentAllocations.map { item in
                let riskWeight = Double.random(in: 20...30)
                return PortfolioItem(
                    symbol: item.symbol,
                    shares: item.shares,
                    value: item.value,
                    percentage: riskWeight,
                    color: item.color
                )
            }
        case .custom:
            return currentAllocations // User would modify these
        }
    }
}

struct AllocationComparisonRow: View {
    let symbol: String
    let currentPercent: Double
    let targetPercent: Double
    let color: Color
    
    var difference: Double {
        targetPercent - currentPercent
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(symbol)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(currentPercent, specifier: "%.1f")%")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("\(targetPercent, specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("\(difference >= 0 ? "+" : "")\(difference, specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(difference >= 0 ? .green : .red)
                .frame(width: 50)
        }
        .padding(.vertical, 4)
    }
}

struct RebalanceImpactView: View {
    var body: some View {
        PremiumGlassContainer(style: .recessed) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rebalancing Impact")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ImpactMetricCard(title: "Estimated Cost", value: "$47.50", description: "Trading fees")
                    ImpactMetricCard(title: "Tax Impact", value: "$234.12", description: "Capital gains")
                    ImpactMetricCard(title: "Cash Required", value: "$1,247", description: "Additional funding")
                    ImpactMetricCard(title: "Risk Reduction", value: "-0.8%", description: "Portfolio volatility")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions Required:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ActionItem(action: "Sell 25 shares of AAPL", amount: "-$4,358")
                        ActionItem(action: "Buy 15 shares of GOOGL", amount: "+$2,138")
                        ActionItem(action: "Buy 5 shares of TSLA", amount: "+$1,259")
                    }
                }
            }
            .padding(20)
        }
    }
}

struct ImpactMetricCard: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            
            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ActionItem: View {
    let action: String
    let amount: String
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundStyle(.blue)
            
            Text(action)
                .font(.caption)
            
            Spacer()
            
            Text(amount)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(amount.starts(with: "+") ? .green : .red)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Image(systemName: trend.iconName)
                    .font(.caption)
                    .foregroundStyle(trend.color)
            }
        }
        .padding()
        .compatibleMaterial(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

enum TrendDirection {
    case up, down, neutral
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }
}

#Preview {
    PremiumTradingView()
}