#!/bin/bash
cd /Users/lupudragos/mytrademate

echo "🧹 Cleaning everything..."
flutter clean
rm -rf ios/Pods ios/.symlinks ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf build/ .dart_tool/

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Installing iOS pods..."
cd ios && pod install && cd ..

echo "🔨 Building..."
flutter build ios --simulator --no-codesign

echo ""
echo "✅ Done! Now run:"
echo "flutter run -d \"iPhone 17 Pro Max\""
