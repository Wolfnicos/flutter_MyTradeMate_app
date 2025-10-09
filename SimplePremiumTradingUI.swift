// Simplified Premium Trading UI for Build Success
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI
import Charts

// MARK: - Main Trading View
struct SimplePremiumTradingView: View {
    @State private var selectedStock = "AAPL"
    @State private var searchText = ""
    @State private var isPresentingDetails = false
    @State private var selectedTimeframe: TimeFrame = .day
    @Namespace private var namespace
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Premium Header
                    SimplePremiumHeader()
                        .padding(.horizontal)
                    
                    // Market Status
                    SimpleMarketStatus()
                        .padding(.horizontal)
                    
                    // Chart
                    SimpleChartCard(selectedStock: $selectedStock)
                        .padding(.horizontal)
                    
                    // Watchlist
                    SimpleWatchlist()
                        .padding(.horizontal)
                    
                    // Portfolio
                    SimplePortfolio()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("MyTradeMate Pro")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search stocks...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "bell.badge.fill")
                            .symbolRenderingMode(.multicolor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Details") {
                        isPresentingDetails = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $isPresentingDetails) {
                SimpleDetailsSheet(stock: selectedStock)
            }
        }
    }
}

// MARK: - Simple Premium Header
struct SimplePremiumHeader: View {
    @State private var totalBalance: Double = 125847.32
    @State private var dayChange: Double = 2347.18
    @State private var dayChangePercent: Double = 1.87
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Portfolio Value")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(totalBalance, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        
                        Text("+$\(dayChange, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("(\(dayChangePercent, specifier: "%.2f")%)")
                            .font(.caption)
                    }
                    .foregroundStyle(dayChange >= 0 ? .green : .red)
                }
            }
            
            // Portfolio health indicator
            HStack {
                Text("Portfolio Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Excellent (84%)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(24)
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Simple Market Status
struct SimpleMarketStatus: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                
                Text("Market Open")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 2h 15m to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                MarketIndicator(symbol: "SPY", change: 0.87)
                MarketIndicator(symbol: "QQQ", change: -0.23)
                MarketIndicator(symbol: "VIX", change: -2.45)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MarketIndicator: View {
    let symbol: String
    let change: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("\(change > 0 ? "+" : "")\(change, specifier: "%.2f")%")
                .font(.caption2)
                .foregroundStyle(change >= 0 ? .green : .red)
        }
    }
}

// MARK: - Simple Chart Card
struct SimpleChartCard: View {
    @Binding var selectedStock: String
    @State private var chartData = generateSampleData()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedStock)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Apple Inc.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Button(timeframe.rawValue) { }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .compatibleMaterial(.ultraThin)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Current price
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$174.32")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                        Text("+2.45 (1.43%)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.green)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Buy") { }
                        .buttonStyle(.borderedProminent)
                    
                    Button("Sell") { }
                        .buttonStyle(.bordered)
                }
            }
            
            // Chart
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
        }
        .padding(24)
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    func generateSampleData() -> [StockDataPoint] {
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let basePrice = 170.0
        
        return (0..<30).map { day in
            let date = Calendar.current.date(byAdding: .day, value: day, to: startDate)!
            let variation = Double.random(in: -5...5)
            let price = basePrice + variation + Double(day) * 0.2
            
            return StockDataPoint(date: date, price: price)
        }
    }
}

// MARK: - Simple Watchlist
struct SimpleWatchlist: View {
    @State private var watchlistItems = generateWatchlist()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Watchlist")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Edit") { }
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 8) {
                ForEach(watchlistItems) { item in
                    SimpleWatchlistRow(item: item)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    func generateWatchlist() -> [WatchlistItem] {
        [
            WatchlistItem(symbol: "AAPL", name: "Apple Inc.", price: 174.32, change: 1.43),
            WatchlistItem(symbol: "MSFT", name: "Microsoft Corp.", price: 378.91, change: -0.87),
            WatchlistItem(symbol: "GOOGL", name: "Alphabet Inc.", price: 142.56, change: 2.14),
            WatchlistItem(symbol: "TSLA", name: "Tesla Inc.", price: 251.83, change: -1.92)
        ]
    }
}

struct SimpleWatchlistRow: View {
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
    }
}

// MARK: - Simple Portfolio
struct SimplePortfolio: View {
    @State private var portfolioItems = generatePortfolio()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Portfolio")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Rebalance") { }
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            // Portfolio chart
            Chart {
                ForEach(portfolioItems) { item in
                    SectorMark(
                        angle: .value("Value", item.percentage),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color.opacity(0.8))
                }
            }
            .frame(height: 150)
            
            // Holdings
            VStack(spacing: 8) {
                ForEach(portfolioItems) { item in
                    SimplePortfolioRow(item: item)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    func generatePortfolio() -> [PortfolioItem] {
        [
            PortfolioItem(symbol: "AAPL", shares: 100, value: 17432, percentage: 35.2, color: .blue),
            PortfolioItem(symbol: "MSFT", shares: 50, value: 18945, percentage: 38.3, color: .green),
            PortfolioItem(symbol: "GOOGL", shares: 75, value: 10692, percentage: 21.6, color: .orange),
            PortfolioItem(symbol: "TSLA", shares: 10, value: 2518, percentage: 5.1, color: .red)
        ]
    }
}

struct SimplePortfolioRow: View {
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

// MARK: - Simple Details Sheet
struct SimpleDetailsSheet: View {
    let stock: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed Analysis for \(stock)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        SimpleMetricCard(title: "P/E Ratio", value: "28.5")
                        SimpleMetricCard(title: "Market Cap", value: "$2.8T")
                        SimpleMetricCard(title: "52W High", value: "$198.23")
                        SimpleMetricCard(title: "52W Low", value: "$124.17")
                    }
                }
                .padding()
            }
            .navigationTitle(stock)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SimpleMetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding()
        .compatibleMaterial(.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SimplePremiumTradingView()
}