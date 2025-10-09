// Advanced Premium Trading Components (Simplified)
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI
import Charts

// MARK: - Refreshable ScrollView
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

// MARK: - Enhanced AI Insights Container
struct EnhancedAIInsightsContainer: View {
    @State private var insights = [
        AIInsight(icon: "brain.head.profile", title: "AI Analysis", 
                 description: "Strong buy signal detected for TSLA with 87% confidence", confidence: 0.87),
        AIInsight(icon: "chart.line.uptrend.xyaxis", title: "Technical Pattern", 
                 description: "Bullish flag pattern forming on NVDA - breakout expected", confidence: 0.73),
        AIInsight(icon: "bell.badge", title: "Options Alert", 
                 description: "Unusual options activity in AAPL - high call volume", confidence: 0.91),
        AIInsight(icon: "eye.fill", title: "Sector Rotation", 
                 description: "AI detects rotation from tech to energy sector", confidence: 0.68)
    ]
    @State private var selectedInsight: AIInsight?
    
    var body: some View {
        PremiumGlassContainer(style: .floating, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("AI-Powered Insights", systemImage: "sparkles")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    
                    Spacer()
                    
                    Button("View All") { }
                        .font(.caption)
                        .buttonStyle(.premium(style: .glass, size: .small))
                }
                
                // Insights carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(insights) { insight in
                            EnhancedInsightCard(
                                insight: insight,
                                isSelected: selectedInsight?.id == insight.id
                            ) {
                                withAnimation(.spring()) {
                                    selectedInsight = insight
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollClipDisabled()
                
                // Detailed view of selected insight
                if let selectedInsight = selectedInsight {
                    InsightDetailView(insight: selectedInsight)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.vertical, 20)
        }
        .pulsingGlass(intensity: 0.2)
    }
}

struct EnhancedInsightCard: View {
    let insight: AIInsight
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundStyle(insight.confidence > 0.8 ? .green : .orange)
                
                Spacer()
                
                ConfidenceBadge(confidence: insight.confidence)
            }
            
            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(insight.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(width: 200, height: 120)
        .background(
            ZStack {
                if isSelected {
                    Material.thick
                    insight.confidence > 0.8 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1)
                } else {
                    Material.regular
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? (insight.confidence > 0.8 ? .green : .orange) : .clear,
                    lineWidth: 1
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .onTapGesture(perform: onTap)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor.opacity(0.2))
            .foregroundStyle(confidenceColor)
            .clipShape(Capsule())
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct InsightDetailView: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                Text("Detailed Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Act on Insight") { }
                    .buttonStyle(.premium(style: .primary, size: .small))
            }
            
            Text("Based on our AI analysis of market patterns, technical indicators, and sentiment data, this insight has been generated with high confidence. Consider this information as part of your broader trading strategy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Set Alert") { }
                    .buttonStyle(.premium(style: .secondary, size: .small))
                
                Button("View Chart") { }
                    .buttonStyle(.premium(style: .glass, size: .small))
                
                Button("Add to Watchlist") { }
                    .buttonStyle(.premium(style: .glass, size: .small))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Advanced 3D Chart Card
struct Advanced3DChartCard: View {
    @Binding var selectedStock: String
    @Binding var timeframe: TimeFrame
    @State private var chartData = StockDataGenerator.generateSampleData()
    @State private var selectedDataPoint: StockDataPoint?
    @State private var showingTechnicalAnalysis = false
    @State private var chartStyle: ChartStyle = .line
    
    enum ChartStyle: String, CaseIterable {
        case line = "Line"
        case candle = "Candle"
        case volume = "Volume"
        case rsi = "RSI"
        
        var iconName: String {
            switch self {
            case .line: return "chart.line.uptrend.xyaxis"
            case .candle: return "chart.bar.xaxis"
            case .volume: return "chart.bar.fill"
            case .rsi: return "waveform.path.ecg"
            }
        }
    }
    
    var body: some View {
        PremiumGlassContainer(style: .elevated, interactions: .morphing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header with stock info and controls
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedStock)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Button(action: {}) {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.premium(style: .glass, size: .small))
                        }
                        
                        Text("Apple Inc.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        EnhancedTimeframeSelector(selectedTimeframe: $timeframe)
                        
                        ChartStyleSelector(selectedStyle: $chartStyle)
                    }
                }
                
                // Current price with live updates
                CurrentPriceDisplay(
                    price: 174.32,
                    change: 2.45,
                    changePercent: 1.43,
                    selectedDataPoint: selectedDataPoint
                )
                
                // Enhanced Chart with interactions
                InteractiveChart(
                    data: chartData,
                    style: chartStyle,
                    selectedPoint: $selectedDataPoint
                )
                .frame(height: showingTechnicalAnalysis ? 300 : 200)
                
                // Technical analysis toggle
                HStack {
                    Button("Technical Analysis") {
                        withAnimation(.spring()) {
                            showingTechnicalAnalysis.toggle()
                        }
                    }
                    .buttonStyle(.premium(style: .secondary, size: .small))
                    
                    Spacer()
                    
                    Button("Full Screen") { }
                        .buttonStyle(.premium(style: .glass, size: .small))
                }
                
                // Technical indicators (when expanded)
                if showingTechnicalAnalysis {
                    TechnicalIndicatorsView()
                        .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(24)
        }
        .animation(.spring(response: 0.6), value: showingTechnicalAnalysis)
    }
}

// MARK: - Enhanced Timeframe Selector
struct EnhancedTimeframeSelector: View {
    @Binding var selectedTimeframe: TimeFrame
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                Button(timeframe.rawValue) {
                    selectedTimeframe = timeframe
                }
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    selectedTimeframe == timeframe ? 
                        Material.thick : Material.ultraThin
                )
                .foregroundStyle(
                    selectedTimeframe == timeframe ? .blue : .primary
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(.easeInOut(duration: 0.2), value: selectedTimeframe)
            }
        }
    }
}

// MARK: - Chart Style Selector
struct ChartStyleSelector: View {
    @Binding var selectedStyle: Advanced3DChartCard.ChartStyle
    
    var body: some View {
        Menu {
            ForEach(Advanced3DChartCard.ChartStyle.allCases, id: \.self) { style in
                Button {
                    selectedStyle = style
                } label: {
                    Label(style.rawValue, systemImage: style.iconName)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedStyle.iconName)
                    .font(.caption)
                Text(selectedStyle.rawValue)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Material.ultraThin)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Current Price Display
struct CurrentPriceDisplay: View {
    let price: Double
    let change: Double
    let changePercent: Double
    let selectedDataPoint: StockDataPoint?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let selected = selectedDataPoint {
                    Text("Selected Point")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(selected.price, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Text(selected.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Current Price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(price, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .contentTransition(.numericText(value: price))
                    
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        
                        Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f") (\(changePercent, specifier: "%.2f")%)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            // Quick action buttons
            VStack(spacing: 8) {
                Button("Buy") { }
                    .buttonStyle(.premium(style: .primary, size: .small))
                
                Button("Sell") { }
                    .buttonStyle(.premium(style: .secondary, size: .small))
            }
        }
    }
}

// MARK: - Interactive Chart
struct InteractiveChart: View {
    let data: [StockDataPoint]
    let style: Advanced3DChartCard.ChartStyle
    @Binding var selectedPoint: StockDataPoint?
    
    var body: some View {
        GeometryReader { geometry in
            Chart {
                ForEach(data) { point in
                    switch style {
                    case .line:
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Price", point.price)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                    case .candle:
                        // Simplified candle representation
                        RectangleMark(
                            x: .value("Time", point.date),
                            yStart: .value("Low", point.price * 0.995),
                            yEnd: .value("High", point.price * 1.005),
                            width: 4
                        )
                        .foregroundStyle(.blue)
                        
                    case .volume:
                        BarMark(
                            x: .value("Time", point.date),
                            y: .value("Volume", Double.random(in: 1000...5000))
                        )
                        .foregroundStyle(.purple.opacity(0.7))
                        
                    case .rsi:
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("RSI", Double.random(in: 30...70))
                        )
                        .foregroundStyle(.orange)
                    }
                    
                    // Selection indicator
                    if let selected = selectedPoint, selected.id == point.id {
                        PointMark(
                            x: .value("Time", point.date),
                            y: .value("Price", point.price)
                        )
                        .foregroundStyle(.orange)
                        .symbolSize(100)
                    }
                }
            }
            .chartBackground { proxy in
                Rectangle()
                    .fill(.clear)
                    .onTapGesture { location in
                        // Handle tap to select data point
                        if let plotFrame = proxy.plotAreaFrame {
                            let relativeXPosition = location.x - plotFrame.origin.x
                            let relativeYPosition = location.y - plotFrame.origin.y
                            
                            // Find closest data point (simplified)
                            if let closest = data.min(by: { abs($0.price - 100) < abs($1.price - 100) }) {
                                selectedPoint = closest
                            }
                        }
                    }
            }
            .animation(.easeInOut, value: selectedPoint)
        }
    }
}

// MARK: - Technical Indicators View
struct TechnicalIndicatorsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Technical Indicators")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                TechnicalIndicatorCard(name: "RSI", value: "67.3", status: .neutral)
                TechnicalIndicatorCard(name: "MACD", value: "+2.45", status: .bullish)
                TechnicalIndicatorCard(name: "BB", value: "Mid", status: .neutral)
                TechnicalIndicatorCard(name: "SMA 20", value: "$171.2", status: .bullish)
                TechnicalIndicatorCard(name: "Volume", value: "High", status: .bullish)
                TechnicalIndicatorCard(name: "ATR", value: "3.2%", status: .neutral)
            }
        }
        .padding(.vertical, 12)
    }
}

struct TechnicalIndicatorCard: View {
    let name: String
    let value: String
    let status: IndicatorStatus
    
    enum IndicatorStatus {
        case bullish, bearish, neutral
        
        var color: Color {
            switch self {
            case .bullish: return .green
            case .bearish: return .red
            case .neutral: return .orange
            }
        }
        
        var iconName: String {
            switch self {
            case .bullish: return "arrow.up"
            case .bearish: return "arrow.down"
            case .neutral: return "minus"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: status.iconName)
                    .font(.caption2)
                    .foregroundStyle(status.color)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(8)
        .background(status.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Options Chain Container
struct OptionsChainContainer: View {
    @State private var selectedExpiry = "Dec 15, 2023"
    @State private var optionsData = OptionsDataGenerator.generateOptionsChain()
    
    var body: some View {
        PremiumGlassContainer(style: .recessed) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Options Chain", systemImage: "link")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Menu(selectedExpiry) {
                        Button("Dec 15, 2023") { selectedExpiry = "Dec 15, 2023" }
                        Button("Jan 19, 2024") { selectedExpiry = "Jan 19, 2024" }
                        Button("Mar 15, 2024") { selectedExpiry = "Mar 15, 2024" }
                    }
                    .buttonStyle(.premium(style: .glass, size: .small))
                }
                
                // Options chain header
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
                .padding(.horizontal)
                
                // Options data
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(optionsData, id: \.strike) { option in
                            OptionsRow(option: option)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(20)
        }
    }
}

struct OptionsRow: View {
    let option: OptionData
    
    var body: some View {
        HStack {
            // Call side
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(option.callPrice, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("Vol: \(option.callVolume)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            // Strike price
            Text("$\(Int(option.strike))")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    option.strike == 175 ? Color.blue.opacity(0.2) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Put side
            VStack(alignment: .leading, spacing: 2) {
                Text("$\(option.putPrice, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("Vol: \(option.putVolume)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .background(Color.clear)
    }
}

// MARK: - Option Data Model
struct OptionData {
    let strike: Double
    let callPrice: Double
    let callVolume: Int
    let putPrice: Double
    let putVolume: Int
}

struct OptionsDataGenerator {
    static func generateOptionsChain() -> [OptionData] {
        let strikes: [Double] = [165, 170, 175, 180, 185]
        return strikes.map { strike in
            OptionData(
                strike: strike,
                callPrice: Double.random(in: 0.5...15.0),
                callVolume: Int.random(in: 10...500),
                putPrice: Double.random(in: 0.5...15.0),
                putVolume: Int.random(in: 10...500)
            )
        }
    }
}