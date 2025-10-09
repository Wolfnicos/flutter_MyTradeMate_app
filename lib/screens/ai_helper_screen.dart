import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dio_binance_client.dart';
import '../services/ohlcv_service.dart';
import '../l10n/strings.dart';
import '../ai/ai_locator.dart';
import '../ai/entities.dart' as ai;

/// AI Helper Screen - Asistent AI dedicat pentru educație crypto și trading
/// Suportă doar: BTC, ETH, BNB, WLFI, TRUMP cu date LIVE
class AIHelperScreen extends StatefulWidget {
  const AIHelperScreen({super.key});

  @override
  State<AIHelperScreen> createState() => _AIHelperScreenState();
}

class _AIHelperScreenState extends State<AIHelperScreen> {
  // 🤖 Use NEW AI Pipeline instead of legacy!
  OHLCVService? _ohlcvService;
  
  // Doar 5 crypto suportate - cu date REALE
  static const List<Map<String, String>> _supportedCrypto = [
    {'symbol': 'BTCUSDT', 'name': 'Bitcoin', 'label': 'BTC'},
    {'symbol': 'ETHUSDT', 'name': 'Ethereum', 'label': 'ETH'},
    {'symbol': 'BNBUSDT', 'name': 'Binance Coin', 'label': 'BNB'},
    {'symbol': 'WLFIUSDT', 'name': 'WLFI Token', 'label': 'WLFI'},
    {'symbol': 'TRUMPUSDT', 'name': 'TRUMP Token', 'label': 'TRUMP'},
  ];

  String _selectedQuote = 'USDT'; // Default: USDT
  final List<String> _availableQuotes = ['USDT', 'USD', 'EUR'];
  
  String? _selectedCrypto = 'BTCUSDT';
  final Map<String, ai.Prediction?> _aiPredictions = {}; // NEW AI predictions!
  final Map<String, Map<String, dynamic>?> _marketData = {};
  bool _loading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadAllData();
    // Auto-refresh la fiecare 30s pentru date LIVE
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAllData(silent: true),
    );
  }

  Future<void> _initServices() async {
    try {
      _ohlcvService = await OHLCVService.createFromPrefs();
      debugPrint('✅ OHLCVService initialized');
    } catch (e) {
      debugPrint('⚠️ OHLCVService init failed: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    // Check if AI is initialized
    if (!AILocator.I.isInitialized) {
      debugPrint('⚠️ AILocator not initialized yet');
      if (!silent && mounted) setState(() => _loading = false);
      return;
    }

    try {
      final client = await DioBinanceClient.createFromPrefs();
      _ohlcvService ??= OHLCVService(client);
      
      for (final crypto in _supportedCrypto) {
        final symbol = _convertSymbol(crypto['symbol']!);
        
        // Verifică dacă simbolul este suportat
        final isSupported = await client.supportsSymbol(symbol);
        if (!isSupported) {
          debugPrint('⚠️ $symbol nu este disponibil pe acest environment');
          continue;
        }

        // Obține date LIVE de piață
        try {
          final ticker = await client.ticker24h(symbol);
          _marketData[crypto['label']!] = ticker;
        } catch (e) {
          debugPrint('Eroare la obținerea datelor pentru $symbol: $e');
        }

        // 🤖 Obține predicție AI via REPOSITORY (cache + consistent!)
        try {
          // Use PredictionRepo pentru cache și consistency!
          final prediction = await AILocator.I.repo.getFor(symbol);
          
          // Store result (poate fi null)
          _aiPredictions[crypto['label']!] = prediction;
          
          // Logs sunt deja în PredictionRepo - nu duplicăm aici!
        } catch (e) {
          _aiPredictions[crypto['label']!] = null;
          debugPrint('❌ Unexpected error for $symbol: $e');
        }
      }
    } catch (e) {
      debugPrint('Eroare la încărcarea datelor: $e');
    }

    if (!silent && mounted) setState(() => _loading = false);
    if (silent && mounted) setState(() {});
  }

  String _convertSymbol(String symbol) {
    if (_selectedQuote == 'USDT') return symbol;
    // Convertește la quote currency selectat
    final base = symbol.replaceAll('USDT', '');
    return '$base$_selectedQuote';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Trading Assistant'),
        actions: [
          // Selector Quote Currency
          DropdownButton<String>(
            value: _selectedQuote,
            dropdownColor: Theme.of(context).cardColor,
            icon: const Icon(Icons.attach_money, color: Colors.white),
            underline: Container(),
            items: _availableQuotes.map((quote) {
              return DropdownMenuItem(
                value: quote,
                child: Text(quote, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedQuote = value);
                _loadAllData();
              }
            },
          ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _loadAllData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildQuoteSelector(),
              const SizedBox(height: 20),
              _buildCryptoGrid(),
              const SizedBox(height: 20),
              if (_selectedCrypto != null) _buildDetailedAnalysis(),
              const SizedBox(height: 20),
              _buildEducationalSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Text(
                  L10n.aiHelperTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              L10n.aiHelperDescription,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildInfoRow('📊', L10n.aiLiveData),
                  const SizedBox(height: 8),
                  _buildInfoRow('🤖', L10n.aiRealTimePredictions),
                  const SizedBox(height: 8),
                  _buildInfoRow('💱', L10n.aiMultiCurrency),
                  const SizedBox(height: 8),
                  _buildInfoRow('🎯', L10n.aiPremiumCrypto),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _buildQuoteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.selectFiatCurrency,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: _availableQuotes.map((quote) {
            final isSelected = quote == _selectedQuote;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedQuote = quote);
                    _loadAllData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.indigo
                        : Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    quote,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCryptoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.premiumCryptoLive,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._supportedCrypto.map((crypto) {
          final label = crypto['label']!;
          final marketData = _marketData[label];
          final prediction = _aiPredictions[label];  // FIX: use _aiPredictions!
          final isSelected = _selectedCrypto == crypto['symbol'];

          return _buildCryptoCard(
            label: label,
            name: crypto['name']!,
            marketData: marketData,
            prediction: prediction,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedCrypto = crypto['symbol']),
          );
        }),
      ],
    );
  }

  Widget _buildCryptoCard({
    required String label,
    required String name,
    required Map<String, dynamic>? marketData,
    required ai.Prediction? prediction,  // NEW AI Prediction type!
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final price = marketData?['lastPrice']?.toString() ?? '---';
    final change24h = marketData?['priceChangePercent']?.toString() ?? '0';
    final changeNum = double.tryParse(change24h) ?? 0;
    final isPositive = changeNum >= 0;

    // Get action from NEW AI prediction
    final action = prediction != null 
        ? AILocator.I.decide(prediction) 
        : 'HOLD';
    final actionColor = action == 'BUY'
        ? Colors.green
        : (action == 'SELL' ? Colors.red : Colors.amber);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.indigo : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$_selectedQuote $price',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isPositive ? '+' : ''}${changeNum.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // AI Prediction (NEW!)
              if (prediction != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: actionColor, width: 1.5),
                  ),
                  child: Text(
                    action,  // From NEW AI!
                    style: TextStyle(
                      color: actionColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedAnalysis() {
    final selectedData = _supportedCrypto.firstWhere(
      (c) => c['symbol'] == _selectedCrypto,
    );
    final label = selectedData['label']!;
    final prediction = _aiPredictions[label];  // FIX: use _aiPredictions!
    final marketData = _marketData[label];

    if (prediction == null && marketData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${L10n.detailedAnalysis} ${selectedData['name']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (prediction != null) _buildPredictionCard(prediction),
        const SizedBox(height: 12),
        if (marketData != null) _buildMarketDataCard(marketData),
      ],
    );
  }

  Widget _buildPredictionCard(ai.Prediction prediction) {  // NEW AI Prediction!
    final action = AILocator.I.decide(prediction);
    final actionColor = action == 'BUY'
        ? Colors.green
        : (action == 'SELL' ? Colors.red : Colors.amber);

    // Get last close for target price
    final lastClose = _marketData[_selectedCrypto?.replaceAll('USDT', '')]?['lastPrice'];
    final lastClosePrice = lastClose != null 
        ? double.tryParse(lastClose.toString()) ?? 0.0 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  L10n.aiPredictionLive,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildMetricRow(L10n.action, action, actionColor),
            _buildMetricRow(
              L10n.confidence,
              '${prediction.confidencePercent.toStringAsFixed(1)}%',  // NEW!
              actionColor,
            ),
            _buildMetricRow(
              L10n.targetPrice,
              '$_selectedQuote ${prediction.targetPrice(lastClosePrice).toStringAsFixed(2)}',  // NEW!
              null,
            ),
            _buildMetricRow(
              L10n.volatility, 
              '${prediction.annVolPercent.toStringAsFixed(1)}%',  // NEW!
              null,
            ),
            _buildMetricRow(
              L10n.probabilityUp,
              '${(prediction.pBuy * 100).toStringAsFixed(1)}%',  // NEW!
              null,
            ),
            _buildMetricRow(
              L10n.estimatedReturn,
              '${prediction.expReturnPercent.toStringAsFixed(2)}%',  // NEW!
              null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketDataCard(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: Colors.cyan),
                const SizedBox(width: 8),
                Text(
                  L10n.marketDataLive,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildMetricRow(
              L10n.price,
              '$_selectedQuote ${data['lastPrice']}',
              null,
            ),
            _buildMetricRow(
              L10n.change24h,
              '${data['priceChangePercent']}%',
              null,
            ),
            _buildMetricRow(L10n.volume24h, '${data['volume']}', null),
            _buildMetricRow(L10n.high24h, '${data['highPrice']}', null),
            _buildMetricRow(L10n.low24h, '${data['lowPrice']}', null),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📚 ${L10n.howItWorks}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildEducationCard(
          '1. ${L10n.liveDataTitle}',
          L10n.liveDataDesc,
          Icons.electric_bolt,
          Colors.orange,
        ),
        _buildEducationCard(
          '2. ${L10n.aiPredictionsTitle}',
          L10n.aiPredictionsDesc,
          Icons.psychology,
          Colors.purple,
        ),
        _buildEducationCard(
          '3. ${L10n.quoteCurrencyTitle}',
          L10n.quoteCurrencyDesc,
          Icons.currency_exchange,
          Colors.green,
        ),
        _buildEducationCard(
          '4. ${L10n.disclaimerAITitle}',
          L10n.disclaimerAIDesc,
          Icons.warning_amber,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildEducationCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

