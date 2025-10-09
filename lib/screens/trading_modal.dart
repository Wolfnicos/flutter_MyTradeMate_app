import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../src/core/trading_prefs.dart' as tp;
import '../services/dio_binance_client.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import '../src/core/order_history.dart' as oh;

class TradingModal extends StatefulWidget {
  final String assetSymbol;
  final bool isBuying;
  final double? initialPrice; // for tests or pre-fetched price
  final Future<bool> Function(double amount)? placeOrderFn; // for tests

  const TradingModal(
      {super.key,
      required this.assetSymbol,
      required this.isBuying,
      this.initialPrice,
      this.placeOrderFn});

  @override
  State<TradingModal> createState() => _TradingModalState();
}

class _TradingModalState extends State<TradingModal> with RestorationMixin {
  String _tradeType = 'Market';
  double _amount = 0.0;
  double? _currentPrice;
  final double _availableBalance = 0.0; // optionally load from prefs later
  final RestorableTextEditingController amountCtl =
      RestorableTextEditingController();
  final TextEditingController _fallbackCtrl = TextEditingController();
  bool _amountListenerAdded = false;
  bool _submitting = false;
  String? _aiRecommendation;
  Color _aiColor = Colors.green;
  bool _restored = false;

  void _ensureAmountListener() {
    if (_amountListenerAdded) return;
    _amountListenerAdded = true;
    final ctrl = _restored ? amountCtl.value : _fallbackCtrl;
    ctrl.addListener(() {
      final v = double.tryParse(ctrl.text.trim());
      if (v != _amount) {
        setState(() => _amount = v ?? 0.0);
      }
    });
  }

  @override
  String? get restorationId => 'trading_modal';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(amountCtl, 'amount');
    _restored = true;
    _ensureAmountListener();
    // migrate any fallback text entered before restoration registration
    if (_fallbackCtrl.text.isNotEmpty &&
        amountCtl.value.text != _fallbackCtrl.text) {
      amountCtl.value.text = _fallbackCtrl.text;
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureAmountListener();
    if (widget.initialPrice != null) {
      _currentPrice = widget.initialPrice;
    } else {
      _loadLive();
    }
  }

  @override
  void dispose() {
    amountCtl.dispose();
    _fallbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLive() async {
    if (!mounted) return;
    final sym = widget.assetSymbol.replaceAll('/', '').toUpperCase();
    final c = await DioBinanceClient.createFromPrefs();
    try {
      final t = await c.ticker24h(sym);
      final raw = (t['lastPrice'] ?? t['price'] ?? t['weightedAvgPrice']);
      setState(() {
        _currentPrice = raw == null ? null : double.tryParse(raw.toString());
      });
    } catch (_) {
      try {
        final p = await c.tickerPrice(sym);
        setState(() => _currentPrice = p);
      } catch (_) {}
    }
    try {
      final pred = await AILocator.I.getPrediction(sym);
      if (pred != null && mounted) {
        final action = AILocator.I.decide(pred);
        final confPct = (pred.confidence() * 100).toStringAsFixed(0);
        final volPct = (pred.annVol * 100).toStringAsFixed(1);
        setState(() {
          _aiRecommendation = '$action • $confPct% • $volPct%';
          _aiColor = action == 'BUY'
              ? Colors.green
              : (action == 'SELL' ? Colors.red : Colors.amber);
        });
      }
    } catch (_) {
      // ignore AI errors — card already shows a friendly fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isBuying
              ? 'Buy ${widget.assetSymbol}'
              : 'Sell ${widget.assetSymbol}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceAndAIInfo(context),
            const SizedBox(height: 25),
            _buildTradeTypeSelector(),
            const SizedBox(height: 25),
            _buildAmountInput(context),
            const SizedBox(height: 15),
            _buildSummaryDetails(),
            const SizedBox(height: 40),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndAIInfo(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Price',
                style: TextStyle(color: Colors.white70)),
            Text(
              _currentPrice == null
                  ? '—'
                  : '\$${_currentPrice!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 25, color: Colors.white12),
            if (_aiRecommendation != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('AI (action • confidence • vol):',
                      style: TextStyle(color: Colors.white70)),
                  Text(_aiRecommendation!,
                      style: TextStyle(
                          color: _aiColor, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildTypeButton('Market', 'Market')),
          Expanded(child: _buildTypeButton('Limit', 'Limit')),
          Expanded(child: _buildTypeButton('Stop-Loss', 'Stop-Loss')),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    final bool isSelected = _tradeType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _tradeType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount (USD)', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        TextField(
          key: tradeAmountFieldKey,
          controller: _restored ? amountCtl.value : _fallbackCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (t) {
            final v = double.tryParse(t.trim());
            setState(() => _amount = v ?? 0.0);
          },
          decoration: InputDecoration(
            hintText: 'Enter amount to invest...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Available Balance: \$${_availableBalance.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildQuickAmountButton('25%', _availableBalance * 0.25),
            _buildQuickAmountButton('50%', _availableBalance * 0.50),
            _buildQuickAmountButton('MAX', _availableBalance),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAmountButton(String label, double value) {
    return TextButton(
      onPressed: () {
        final v = value.clamp(0, double.infinity).toDouble();
        if (_restored) {
          amountCtl.value.text = v.toStringAsFixed(2);
        } else {
          _fallbackCtrl.text = v.toStringAsFixed(2);
        }
        setState(() => _amount = v);
      },
      child: Text(label, style: const TextStyle(color: Colors.indigoAccent)),
    );
  }

  Widget _buildSummaryDetails() {
    final price = _currentPrice ?? 0;
    final double estimatedUnits =
        (_amount > 0 && price > 0) ? _amount / price : 0.0;
    final double fee = _amount * 0.001;
    final double totalCost = _amount + fee;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          _buildSummaryRow(
              'Estimated Units:',
              '${estimatedUnits.toStringAsFixed(6)} ${widget.assetSymbol}',
              Colors.white),
          _buildSummaryRow('Trading Fee (0.1%):', '\$${fee.toStringAsFixed(2)}',
              Colors.orange),
          const Divider(height: 25, color: Colors.white12),
          _buildSummaryRow('Total Cost:', '\$${totalCost.toStringAsFixed(2)}',
              Colors.cyanAccent,
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                color: isTotal ? Colors.white : Colors.white70,
                fontSize: isTotal ? 16 : 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final actionColor =
        widget.isBuying ? Colors.green.shade600 : Colors.red.shade600;
    final actionText = widget.isBuying ? 'Confirm Buy' : 'Confirm Sell';

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        key: tradeConfirmBtnKey,
        onPressed: (_amount > 0 && _currentPrice != null && !_submitting)
            ? () async {
                setState(() => _submitting = true);
                // Only Market orders are supported for now
                if (_tradeType != 'Market') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Only Market orders are supported right now. Limit/Stop-Loss coming soon.')),
                    );
                  }
                  setState(() => _submitting = false);
                  return;
                }
                // Optional: simple balance check (if balance is known)
                if (_availableBalance > 0 && _amount > _availableBalance) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Amount exceeds available balance (\$${_availableBalance.toStringAsFixed(2)}).')),
                    );
                  }
                  setState(() => _submitting = false);
                  return;
                }
                try {
                  // If injected handler is provided (tests), use it for deterministic behavior
                  if (widget.placeOrderFn != null) {
                    final ok = await widget.placeOrderFn!(_amount);
                    if (mounted) {
                      if (ok) {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Order sent (test harness)')),
                        );
                        Navigator.of(context).maybePop();
                      } else {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Order failed (test harness)')),
                        );
                      }
                    }
                    return;
                  }
                  final prefs = await tp.TradingPrefs.load();
                  if ((prefs.apiKey?.isEmpty ?? true) ||
                      (prefs.apiSecret?.isEmpty ?? true)) {
                    throw Exception(
                        'API keys missing. Open Settings and add your Binance API key & secret.');
                  }
                  final client = await DioBinanceClient.createFromPrefs();
                  // Normalize symbol
                  final sym =
                      widget.assetSymbol.replaceAll('/', '').toUpperCase();
                  // Pre-validate: clamp to MIN_NOTIONAL if needed
                  var q = _amount.isFinite && _amount > 0 ? _amount : 0.0;
                  if (q == 0.0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Enter a valid amount greater than 0.')),
                      );
                    }
                    setState(() => _submitting = false);
                    return;
                  }
                  try {
                    q = (await client.clampQuoteToMinNotional(sym, q))
                        .toDouble();
                  } catch (_) {
                    // continue with provided amount if clamp helper not available
                  }
                  final res = await client.newOrderMarketDouble(
                    symbol: sym,
                    side: widget.isBuying ? 'BUY' : 'SELL',
                    quoteQty: q,
                  );
                  final order = oh.Order(
                    id: (res['orderId']?.toString() ?? 'N/A'),
                    symbol: sym,
                    side: widget.isBuying ? 'BUY' : 'SELL',
                    quoteQty: q,
                    executedQty: double.tryParse((res['executedQty'] ??
                            res['cummulativeQuoteQty'] ??
                            '0')
                        .toString()),
                    status: (res['status'] ?? 'UNKNOWN').toString(),
                    env: (prefs.env == tp.TradeEnv.testnet)
                        ? oh.TradeEnv.testnet
                        : oh.TradeEnv.live,
                  );
                  await oh.OrderHistoryRepository.instance.addOrder(order);
                  HapticFeedback.lightImpact();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order sent (testnet)')),
                    );
                    Navigator.of(context).maybePop();
                  }
                } catch (e) {
                  HapticFeedback.selectionClick();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Order failed: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          disabledBackgroundColor: actionColor.withValues(alpha: 102),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _submitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                actionText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

@visibleForTesting
String? validateQuoteForTest(num? q) {
  if (q == null) return 'Amount required';
  if (q <= 0) return 'Amount must be > 0';
  return null;
}

@visibleForTesting
bool isPlaceEnabledForTest(num? q) => validateQuoteForTest(q) == null;

@visibleForTesting
const amountFieldKey = Key('trading_modal.amount');

@visibleForTesting
const placeOrderBtnKey = Key('trading_modal.place');

@visibleForTesting
const tradeConfirmBtnKey = Key('trade.confirm');

@visibleForTesting
const tradeAmountFieldKey = Key('trade.amount');
