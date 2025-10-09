#!/bin/bash
# MyTradeMate - Complete Build Script

echo "🚀 MyTradeMate AI Pipeline - Build Script"
echo "=========================================="
echo ""

# Step 1: Clean
echo "🧹 Step 1: Cleaning..."
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/build build/ .dart_tool/

# Step 2: Dependencies
echo "📦 Step 2: Getting dependencies..."
flutter pub get

# Step 3: iOS Pods
echo "🍎 Step 3: Installing iOS pods..."
cd ios && pod install && cd ..

# Step 4: Build
echo "🔨 Step 4: Building iOS..."
flutter build ios --simulator --no-codesign

# Step 5: Done
echo ""
echo "✅ Build complete!"
echo ""
echo "Run with: flutter run -d \"iPhone 17 Pro Max\""
echo ""
