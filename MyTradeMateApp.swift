// MyTradeMate Premium App Entry Point
// Copyright 2025 MyTradeMate Premium UI

import SwiftUI

@main
struct MyTradeMateApp: App {
    var body: some Scene {
        WindowGroup {
            SimplePremiumTradingView()
                .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    SimplePremiumTradingView()
        .preferredColorScheme(.dark)
}