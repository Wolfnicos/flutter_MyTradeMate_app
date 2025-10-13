import 'package:flutter/material.dart';
import 'package:mytrademate/services/ohlcv_service.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/backtesting/backtest_result.dart' as bt;
import 'package:mytrademate/backtesting/metrics_calculator.dart' as mc;
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'package:mytrademate/backtesting/backtester_report_adapter.dart';
import 'package:mytrademate/widgets/premium_widgets.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final List<String> _symbols = [
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'WLFIUSDT',
    'TRUMPUSDT'
  ];
  String _selectedSymbol = 'BTCUSDT';
  String _selectedInterval = '5m';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  double _initialCapital = 10000.0;
  double _positionSize = 0.1; // 10% of capital per trade
  bool _useEnsemble = true;
  String _strategy = 'ensemble'; // ensemble | hybrid1..hybrid5
  final String _selectedStrategy = 'Hybrid 1: EMA+RSI+Cloud';

  bool _isRunning = false;
  BacktestResult? _result;
  bt.BacktestResult? _rawResult;
  String? _error;
  OHLCVService? _ohlcv;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backtesting & Simulation',
              style: TextStyle(color: kText, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            labelColor: kHold,
            unselectedLabelColor: kText2,
            indicatorColor: kHold,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Trades'),
              Tab(text: 'Equity'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildSummaryTab(),
          _buildTradesTab(),
          _buildEquityTab(),
          _buildSettingsTab(),
        ]),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernCard(
            accentColor: Colors.blue,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backtesting for Analysis',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: kText)),
                      SizedBox(height: 6),
                      Text(
                        'Use backtest results to understand AI behavior. Current model shows 30% win rate - NOT ready for live trading.',
                        style: TextStyle(fontSize: 12, color: kText2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null) _buildResultsCard(),
          const SizedBox(height: 16),
          if (_isRunning)
            const ModernCard(
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            GradientButton(
              label: 'Run Backtest',
              gradientColors: const [Colors.indigo, Colors.cyan],
              onPressed: _runBacktest,
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ModernCard(
              accentColor: Colors.red,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: kText)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradesTab() {
    if (_rawResult == null || _rawResult!.trades.isEmpty) {
      return const Center(
          child: Text('No trades yet. Run a backtest.',
              style: TextStyle(color: kText2)));
    }
    final trades = _rawResult!.trades;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, i) {
        final t = trades[i];
        final isWin = t.pnl >= 0;
        final pnlColor = isWin ? const Color(0xFF10B981) : kSell;
        return ModernCard(
          hasGlow: false,
          child: Row(
            children: [
              ActionBadge(action: t.action),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.action} @ ${t.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: kText, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(t.time),
                        style: const TextStyle(color: kText2, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(t.pnl.toStringAsFixed(2),
                      style: TextStyle(
                          color: pnlColor, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const SizedBox(height: 2),
                  Text('Fee ${t.fee.toStringAsFixed(4)}',
                      style: const TextStyle(color: kText2, fontSize: 12)),
                ],
              )
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: trades.length,
    );
  }

  Widget _buildEquityTab() {
    if (_rawResult == null || _rawResult!.equity.isEmpty) {
      return const Center(
          child: Text('No equity curve yet. Run a backtest.',
              style: TextStyle(color: kText2)));
    }
    final eq = _rawResult!.equity;
    final spots = <FlSpot>[];
    for (int i = 0; i < eq.length; i++) {
      spots.add(FlSpot(i.toDouble(), eq[i]));
    }

    final equityBar = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: kNeon,
      barWidth: 2.2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [kNeon.withOpacity(0.25), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ModernCard(
        accentColor: kNeon,
        child: SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [equityBar],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kText2),
          filled: true,
          fillColor: Colors.white.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kHold, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: ModernCard(
        accentColor: kHold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configurare Backtest',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kText)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSymbol,
              decoration: decoration('Symbol'),
              dropdownColor: kCard,
              items: _symbols
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSymbol = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedInterval,
              decoration: decoration('Interval'),
              dropdownColor: kCard,
              items: ['5m', '15m', '1h', '4h', '1d']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedInterval = v!),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ListTile(
                  title: const Text('Start', style: TextStyle(color: kText2)),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate),
                      style: const TextStyle(color: kText)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _startDate = date);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('End', style: TextStyle(color: kText2)),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate),
                      style: const TextStyle(color: kText)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('Use Ensemble', style: TextStyle(color: kText)),
              value: _useEnsemble,
              onChanged: (v) => setState(() => _useEnsemble = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _strategy,
              decoration: decoration('Strategy'),
              dropdownColor: kCard,
              items: const [
                DropdownMenuItem(
                    value: 'ensemble', child: Text('AI Ensemble (default)')),
                DropdownMenuItem(
                    value: 'hybrid1', child: Text('Hybrid 1: EMA+RSI+Cloud')),
                DropdownMenuItem(
                    value: 'hybrid2', child: Text('Hybrid 2: BB+ADX+Cloud')),
                DropdownMenuItem(
                    value: 'hybrid3', child: Text('Hybrid 3: Trend+RSI')),
                DropdownMenuItem(
                    value: 'hybrid4', child: Text('Hybrid 4: Breakout+DailyTrend')),
                DropdownMenuItem(
                    value: 'hybrid5', child: Text('Hybrid 5: Vol-adaptive+Cloud')),
              ],
              onChanged: (v) => setState(() => _strategy = v ?? 'ensemble'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: decoration('Initial Capital (USDT)'),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _initialCapital.toString()),
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null) _initialCapital = val;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: decoration('Position Size (fraction, e.g. 0.1 = 10%)'),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _positionSize.toString()),
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null) _positionSize = val.clamp(0.01, 1.0);
              },
            ),
            const SizedBox(height: 16),
            if (_isRunning)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              GradientButton(
                label: 'Run Backtest',
                gradientColors: const [Colors.indigo, Colors.cyan],
                onPressed: _runBacktest,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ModernCard(
                accentColor: Colors.red,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: kText)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final r = _result!;
    final pnlColor = r.totalPnl >= 0 ? Colors.green : Colors.red;
    final winRate =
        r.totalTrades > 0 ? (r.winningTrades / r.totalTrades) * 100 : 0.0;
    final merit = mc.MetricsCalculator.meritFromBacktest(
      _rawResult?.equity ?? const [],
      totalReturn: r.returnPercent,
      wins: r.winningTrades,
      trades: r.totalTrades,
      maxDd: r.maxDrawdown,
    );
    final decision = mc.MetricsCalculator.meritDecision(merit);

    return ModernCard(
      accentColor: pnlColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rezultate Backtest',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kText)),
          const SizedBox(height: 12),
          _buildResultRow('Capital Initial', '\$${r.initialCapital.toStringAsFixed(2)}'),
          _buildResultRow('Capital Final', '\$${r.finalCapital.toStringAsFixed(2)}'),
          _buildResultRow(
            'P&L Total',
            '\$${r.totalPnl.toStringAsFixed(2)} (${r.returnPercent.toStringAsFixed(2)}%)',
            valueColor: pnlColor,
          ),
          const Divider(height: 24),
          _buildResultRow('Total Trades', '${r.totalTrades}'),
          _buildResultRow('Winning Trades', '${r.winningTrades}'),
          _buildResultRow('Losing Trades', '${r.losingTrades}'),
          _buildResultRow('Win Rate', '${winRate.toStringAsFixed(1)}%'),
          const Divider(height: 24),
          _buildResultRow('Avg Win', '\$${r.avgWin.toStringAsFixed(2)}'),
          _buildResultRow('Avg Loss', '\$${r.avgLoss.toStringAsFixed(2)}'),
          _buildResultRow('Max Drawdown', '${r.maxDrawdown.toStringAsFixed(2)}%', valueColor: Colors.red),
          const Divider(height: 24),
          _buildResultRow('Sharpe Ratio', r.sharpeRatio.toStringAsFixed(2)),
          _buildResultRow('Fees Paid', '\$${r.totalFees.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildResultRow('Merit Score', merit.toStringAsFixed(2)),
          _buildResultRow('Decision', decision),
          if (merit > 8.0 && _strategy != 'ensemble') ...[
            const SizedBox(height: 12),
            GradientButton(
              label: 'Set as Default Strategy',
              gradientColors: const [Colors.teal, Colors.greenAccent],
              onPressed: () async {
                final prefs = await TradingPrefs.load();
                await prefs.setDefaultStrategy(_strategy);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Default strategy set to ${_strategy.toUpperCase()}')),
                );
              },
            )
          ]
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: kText2)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? kText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runBacktest() async {
    setState(() {
      _isRunning = true;
      _error = null;
      _result = null;
    });

    try {
      _ohlcv ??= await OHLCVService.createFromPrefs();
      BacktestReport report;
      if (!_useEnsemble && _selectedStrategy.startsWith('Hybrid')) {
        debugPrint('🔧 Using BacktesterV2 with strategy: $_selectedStrategy');
        final backtesterV2 = BacktesterV2(
          engine: AILocator.I.engine,
          ohlcv: _ohlcv!,
          strategyName: _selectedStrategy,
        );
        report = await backtesterV2.run(
          symbol: _selectedSymbol,
          interval: _selectedInterval,
          initialCapital: _initialCapital,
          window: 64,
          horizon: 1,
          positionSize: _positionSize,
          ensemble: null,
        );
      } else {
        debugPrint('🔧 Using original Backtester');
        final backtester = Backtester(
          engine: AILocator.I.engine,
          ohlcv: _ohlcv!,
        );
        final oldResult = await backtester.run(
          symbol: _selectedSymbol,
          interval: _selectedInterval,
          initialCapital: _initialCapital,
          window: 64,
          horizon: 1,
          positionSize: _positionSize,
          ensemble: _useEnsemble ? AILocator.I.ensemble : null,
        );
        // Normalize to BacktestReport units (percent for returns/drawdown) and include trades
        report = BacktestReport(
          initialCapital: oldResult.initialCapital,
          finalCapital: oldResult.finalCapital,
          totalReturn: oldResult.totalReturn * 100.0,
          numTrades: oldResult.numTrades,
          winningTrades: oldResult.winningTrades,
          losingTrades: oldResult.losingTrades,
          avgWin: oldResult.avgWin,
          avgLoss: oldResult.avgLoss,
          maxDrawdown: oldResult.maxDrawdown * 100.0,
          sharpe: oldResult.sharpe,
          feesPaid: oldResult.feesPaid,
          times: oldResult.times,
          equity: oldResult.equity,
          trades: oldResult.trades
              .map((t) => {
                    'time': t.time,
                    'action': t.action,
                    'price': t.price,
                    'qty': t.qty,
                    'fee': t.fee,
                    'pnl': t.pnl,
                  })
              .toList(),
        );
      }

      setState(() {
        // Convert BacktestReport (percent units) back to BacktestResult (fraction for returns)
        final tradeRecords = report.trades
            .map((m) => bt.TradeRecord(
                  time: m['time'] as DateTime,
                  action: (m['action'] as String?) ?? 'HOLD',
                  price: (m['price'] as num).toDouble(),
                  qty: (m['qty'] as num).toDouble(),
                  fee: (m['fee'] as num).toDouble(),
                  pnl: (m['pnl'] as num).toDouble(),
                ))
            .toList();
        _rawResult = bt.BacktestResult(
          start: report.times.isEmpty ? DateTime.now() : report.times.first,
          end: report.times.isEmpty ? DateTime.now() : report.times.last,
          symbol: _selectedSymbol,
          interval: _selectedInterval,
          times: report.times,
          equity: report.equity,
          initialCapital: report.initialCapital,
          finalCapital: report.finalCapital,
          totalReturn: report.totalReturn / 100.0,
          numTrades: report.numTrades,
          winningTrades: report.winningTrades,
          losingTrades: report.losingTrades,
          avgWin: report.avgWin,
          avgLoss: report.avgLoss,
          maxDrawdown: report.maxDrawdown / 100.0,
          sharpe: report.sharpe,
          feesPaid: report.feesPaid,
          trades: tradeRecords,
        );
        _result = BacktestResult(
          initialCapital: report.initialCapital,
          finalCapital: report.finalCapital,
          totalPnl: report.finalCapital - report.initialCapital,
          returnPercent: report.totalReturn,
          totalTrades: report.numTrades,
          winningTrades: report.winningTrades,
          losingTrades: report.losingTrades,
          avgWin: report.avgWin,
          avgLoss: report.avgLoss,
          maxDrawdown: report.maxDrawdown,
          sharpeRatio: report.sharpe,
          totalFees: report.feesPaid,
        );
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRunning = false;
      });
    }
  }
}

class BacktestResult {
  final double initialCapital;
  final double finalCapital;
  final double totalPnl;
  final double returnPercent;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double avgWin;
  final double avgLoss;
  final double maxDrawdown;
  final double sharpeRatio;
  final double totalFees;

  BacktestResult({
    required this.initialCapital,
    required this.finalCapital,
    required this.totalPnl,
    required this.returnPercent,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.avgWin,
    required this.avgLoss,
    required this.maxDrawdown,
    required this.sharpeRatio,
    required this.totalFees,
  });
}
