// Advanced Notification & Alert System for Premium Trading
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI
import UserNotifications

// MARK: - Premium Notification System
class PremiumNotificationManager: ObservableObject {
    @Published var alerts: [TradingAlert] = []
    @Published var notifications: [TradingNotification] = []
    
    static let shared = PremiumNotificationManager()
    
    private init() {
        setupSampleData()
    }
    
    func addAlert(_ alert: TradingAlert) {
        withAnimation(.spring()) {
            alerts.insert(alert, at: 0)
        }
    }
    
    func removeAlert(_ alert: TradingAlert) {
        withAnimation(.easeInOut) {
            alerts.removeAll { $0.id == alert.id }
        }
    }
    
    func addNotification(_ notification: TradingNotification) {
        withAnimation(.spring()) {
            notifications.insert(notification, at: 0)
        }
        
        // Remove after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(notification.duration)) {
            self.removeNotification(notification)
        }
    }
    
    private func removeNotification(_ notification: TradingNotification) {
        withAnimation(.easeInOut) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    private func setupSampleData() {
        alerts = [
            TradingAlert(
                type: .priceTarget,
                symbol: "AAPL",
                title: "Price Target Reached",
                message: "AAPL has reached your target price of $175.00",
                targetPrice: 175.00,
                currentPrice: 175.23,
                priority: .high
            ),
            TradingAlert(
                type: .volatility,
                symbol: "TSLA",
                title: "High Volatility Alert",
                message: "TSLA showing unusual volatility (+15% in 1hr)",
                targetPrice: nil,
                currentPrice: 251.83,
                priority: .medium
            ),
            TradingAlert(
                type: .news,
                symbol: "NVDA",
                title: "News Alert",
                message: "Breaking: NVIDIA announces new AI chip partnership",
                targetPrice: nil,
                currentPrice: 876.45,
                priority: .high
            )
        ]
    }
}

// MARK: - Trading Alert Model
struct TradingAlert: Identifiable, Hashable {
    let id = UUID()
    let type: AlertType
    let symbol: String
    let title: String
    let message: String
    let targetPrice: Double?
    let currentPrice: Double
    let priority: Priority
    let timestamp = Date()
    
    enum AlertType: CaseIterable {
        case priceTarget
        case volatility
        case volume
        case news
        case technical
        case earnings
        
        var iconName: String {
            switch self {
            case .priceTarget: return "target"
            case .volatility: return "waveform.path.ecg"
            case .volume: return "chart.bar.fill"
            case .news: return "newspaper.fill"
            case .technical: return "chart.line.uptrend.xyaxis"
            case .earnings: return "dollarsign.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .priceTarget: return .green
            case .volatility: return .orange
            case .volume: return .blue
            case .news: return .purple
            case .technical: return .cyan
            case .earnings: return .mint
            }
        }
    }
    
    enum Priority: CaseIterable {
        case low, medium, high, urgent
        
        var color: Color {
            switch self {
            case .low: return .secondary
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }
    }
}

// MARK: - Trading Notification Model
struct TradingNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let action: NotificationAction?
    let duration: TimeInterval
    
    enum NotificationType {
        case success
        case warning
        case error
        case info
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
    }
    
    struct NotificationAction {
        let title: String
        let action: () -> Void
    }
}

// MARK: - Premium Alert Center View
struct PremiumAlertCenter: View {
    @StateObject private var notificationManager = PremiumNotificationManager.shared
    @State private var selectedFilter: AlertFilter = .all
    @State private var isExpanded = false
    
    enum AlertFilter: String, CaseIterable {
        case all = "All"
        case high = "High Priority"
        case today = "Today"
        case priceTargets = "Price Targets"
        
        func matches(_ alert: TradingAlert) -> Bool {
            switch self {
            case .all: return true
            case .high: return alert.priority == .high || alert.priority == .urgent
            case .today: return Calendar.current.isDateInToday(alert.timestamp)
            case .priceTargets: return alert.type == .priceTarget
            }
        }
    }
    
    var filteredAlerts: [TradingAlert] {
        notificationManager.alerts.filter { selectedFilter.matches($0) }
    }
    
    var body: some View {
        NavigationStack {
            PremiumGlassContainer(style: .floating) {
                VStack(spacing: 0) {
                    // Header with filter
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Alert Center")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(filteredAlerts.count) active alerts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(AlertFilter.allCases, id: \.self) { filter in
                                Button(filter.rawValue) {
                                    selectedFilter = filter
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedFilter.rawValue)
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // Quick stats
                    HStack(spacing: 16) {
                        AlertStatCard(
                            title: "High Priority",
                            count: notificationManager.alerts.filter { $0.priority == .high || $0.priority == .urgent }.count,
                            color: .red
                        )
                        
                        AlertStatCard(
                            title: "Price Targets",
                            count: notificationManager.alerts.filter { $0.type == .priceTarget }.count,
                            color: .green
                        )
                        
                        AlertStatCard(
                            title: "News",
                            count: notificationManager.alerts.filter { $0.type == .news }.count,
                            color: .purple
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Alerts list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredAlerts) { alert in
                                PremiumAlertCard(alert: alert) {
                                    notificationManager.removeAlert(alert)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxHeight: 400)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Alert Stat Card
struct AlertStatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Premium Alert Card
struct PremiumAlertCard: View {
    let alert: TradingAlert
    let onDismiss: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        PremiumGlassContainer(style: .elevated, interactions: .morphing) {
            VStack(spacing: 0) {
                // Main content
                HStack(alignment: .top, spacing: 16) {
                    // Alert icon
                    Image(systemName: alert.type.iconName)
                        .font(.title3)
                        .foregroundStyle(alert.type.color)
                        .frame(width: 24, height: 24)
                    
                    // Alert content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(alert.symbol)
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            // Priority badge
                            Text(alert.priority.rawValue.capitalized)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(alert.priority.color.opacity(0.2))
                                .foregroundStyle(alert.priority.color)
                                .clipShape(Capsule())
                            
                            // Dismiss button
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Text(alert.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(alert.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Price information
                        if let targetPrice = alert.targetPrice {
                            HStack {
                                Text("Target: $\(targetPrice, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("Current: $\(alert.currentPrice, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Timestamp
                        Text(alert.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
                
                // Expandable actions
                if isExpanded {
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button("View Chart") {
                            // Navigate to chart
                        }
                        .buttonStyle(.premium(style: .secondary, size: .small))
                        
                        Button("Set New Alert") {
                            // Create new alert
                        }
                        .buttonStyle(.premium(style: .glass, size: .small))
                        
                        Spacer()
                        
                        Button("Mark as Read") {
                            onDismiss()
                        }
                        .buttonStyle(.premium(style: .primary, size: .small))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring()) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Floating Notification Overlay
struct FloatingNotificationOverlay: View {
    @StateObject private var notificationManager = PremiumNotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                FloatingNotificationCard(notification: notification)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60) // Account for safe area
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

struct FloatingNotificationCard: View {
    let notification: TradingNotification
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.iconName)
                .foregroundStyle(notification.type.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let action = notification.action {
                Button(action.title) {
                    action.action()
                }
                .font(.caption)
                .buttonStyle(.premium(style: .glass, size: .small))
            }
        }
        .padding(16)
        .background(
            ZStack {
                Material.thick
                notification.type.color.opacity(0.1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.x > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.x > 100 {
                        withAnimation(.easeOut) {
                            dragOffset = CGSize(width: 400, height: 0)
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }
}