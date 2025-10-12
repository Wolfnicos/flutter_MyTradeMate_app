# 🚀 Quick Start - AI Trading Assistant

## Pornire Rapidă (3 pași simpli)

### 1️⃣ **Rulează Aplicația**
```bash
cd /Users/lupudragos/mytrademate
flutter run
```

Sau pentru iOS Simulator:
```bash
flutter run -d "iPhone 17 Pro Max"
```

### 2️⃣ **Deschide AI Helper**
1. Aplicația pornește pe **Dashboard**
2. Scroll down puțin
3. Apasă pe butonul mare **"🤖 AI Trading Assistant (LIVE)"**

### 3️⃣ **Explorează**
- **Selectează Quote Currency**: Apasă dropdown-ul din toolbar (USDT/USD/EUR)
- **Vezi Prețuri LIVE**: Toate cele 5 crypto au prețuri în timp real
- **Click pe o Crypto**: Vezi analiza AI detaliată
- **Pull to Refresh**: Trage în jos pentru date fresh

---

## 🎯 Cele 5 Crypto Disponibile

| # | Crypto | Testnet | Mainnet |
|---|--------|---------|---------|
| 1 | **BTC** - Bitcoin | ✅ | ✅ |
| 2 | **ETH** - Ethereum | ✅ | ✅ |
| 3 | **BNB** - Binance Coin | ✅ | ✅ |
| 4 | **WLFI** - WLFI Token | ❌ | ✅ |
| 5 | **TRUMP** - TRUMP Token | ❌ | ✅ |

**💡 Tip:** Pentru a vedea toate 5 crypto, conectează-te la **Binance Mainnet** în Settings.

---

## 💱 Schimbă Moneda Fiat

În AI Helper screen (toolbar, sus-dreapta):
- Apasă pe **💲** icon dropdown
- Selectează: **USDT** / **USD** / **EUR**
- Prețurile se actualizează automat

---

## 🤖 Ce înseamnă Predicțiile AI?

### **BUY (Verde)** 🟢
- AI recomandă cumpărare
- Trend pozitiv detectat
- Încredere ≥ 60%

### **SELL (Roșu)** 🔴
- AI recomandă vânzare
- Trend negativ detectat
- Încredere ≥ 60%

### **HOLD (Galben)** 🟡
- AI recomandă menținere
- Piață incertă
- Încredere 40-60%

**⚠️ Important:** Acestea sunt **orientative**, nu sfaturi financiare!

---

## 📊 Date Disponibile

Pentru fiecare crypto vezi:
- 💵 **Preț LIVE** (în USDT/USD/EUR)
- 📈 **Schimbare 24h** (%)
- 📊 **Volum 24h**
- 🎯 **Predicție AI** (BUY/SELL/HOLD)
- 💪 **Încredere** (0-100%)
- 🎯 **Țintă Preț**
- ⚡ **Volatilitate** (LOW/MEDIUM/HIGH)

---

## 🔄 Auto-Refresh

Datele se actualizează automat:
- ⏱️ **La fiecare 30 secunde**
- 🔄 **Manual**: Pull down to refresh
- 🔴 **Indicator loading**: Vezi când se actualizează

---

## ⚙️ Settings Binance

Pentru a configura Mainnet/Testnet:
1. Dashboard → Apasă icon **Settings** (⚙️)
2. Scroll la **"Binance Configuration"**
3. Alege:
   - **Testnet**: Pentru testing (BTC, ETH, BNB)
   - **Mainnet**: Pentru date complete (toate 5 crypto)

**⚠️ Atenție:** Mainnet folosește chei API reale!

---

## 🐛 Troubleshooting

### Problema: "Crypto nu este disponibil"
**Soluție:** 
- Verifică că ești pe **Mainnet** pentru WLFI și TRUMP
- BTC, ETH, BNB funcționează pe ambele (Testnet și Mainnet)

### Problema: "AI unavailable"
**Soluție:**
- Verifică conexiunea la internet
- Pull down pentru refresh
- Restartează aplicația

### Problema: "Prețuri nu se actualizează"
**Soluție:**
- Apasă butonul **Refresh** (🔄)
- Pull down pentru refresh manual
- Verifică Settings → Binance API keys

---

## 📚 Învață Mai Mult

- **Full Documentation**: Vezi `AI_HELPER_README.md`
- **Model Details**: Vezi `docs/ModelCard.md`
- **Testing**: Rulează `flutter test test/ai_helper_live_test.dart`

---

## 🎓 Pentru Dezvoltatori

### Cod sursă principal:
- `lib/screens/ai_helper_screen.dart` - UI principal
- `lib/services/ai_service.dart` - AI logic
- `lib/services/dio_binance_client.dart` - Binance API

### Testare:
```bash
# Test AI cu date LIVE
flutter test test/ai_helper_live_test.dart

# Test complet
flutter test

# Analyze
flutter analyze
```

### Build:
```bash
# iOS
flutter build ios --simulator --no-codesign

# Android
flutter build apk --release
```

---

**🎉 Gata! Enjoy trading cu AI!**

Pentru suport: Consultă `AI_HELPER_README.md` pentru detalii complete.





