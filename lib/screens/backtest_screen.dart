import 'package:flutter/material.dart';
import 'package:mytrademate/services/ohlcv_service.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/backtesting/backtest_result.dart' as bt;
import 'package:mytrademate/backtesting/hybrid_backtester.dart';
import 'package:mytrademate/backtesting/metrics_calculator.dart' as mc;
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'package:mytrademate/backtesting/backtester_report_adapter.dart';

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
          title: const Text('Backtesting & Simulation'),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(tabs: [
            Tab(text: 'Summary'),
            Tab(text: 'Trades'),
            Tab(text: 'Equity'),
            Tab(text: 'Settings'),
          ]),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backtesting for Analysis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use backtest results to understand AI behavior. Current model shows 30% win rate - NOT ready for live trading.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_result != null) _buildResultsCard(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isRunning ? null : _runBacktest,
            icon: _isRunning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? 'Running...' : 'Run Backtest'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradesTab() {
    if (_rawResult == null || _rawResult!.trades.isEmpty) {
      return const Center(child: Text('No trades yet. Run a backtest.'));
    }
    final trades = _rawResult!.trades;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, i) {
        final t = trades[i];
        final pnlColor = t.pnl >= 0 ? Colors.green : Colors.red;
        return ListTile(
          dense: true,
          title: Text('${t.action}  @ ${t.price.toStringAsFixed(2)}'),
          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(t.time)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.pnl.toStringAsFixed(2), style: TextStyle(color: pnlColor)),
              Text('Fee ${t.fee.toStringAsFixed(4)}'),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: trades.length,
    );
  }

  Widget _buildEquityTab() {
    if (_rawResult == null || _rawResult!.equity.isEmpty) {
      return const Center(child: Text('No equity curve yet. Run a backtest.'));
    }
    final eq = _rawResult!.equity;
    final spots = <FlSpot>[];
    for (int i = 0; i < eq.length; i++) {
      spots.add(FlSpot(i.toDouble(), eq[i]));
    }

    final equityBar = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: Colors.tealAccent,
      barWidth: 2.2,
      dotData: const FlDotData(show: false),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [equityBar],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configurare Backtest',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSymbol,
                decoration: const InputDecoration(
                    labelText: 'Symbol', border: OutlineInputBorder()),
                items: _symbols
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSymbol = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedInterval,
                decoration: const InputDecoration(
                    labelText: 'Interval', border: OutlineInputBorder()),
                items: ['5m', '15m', '1h', '4h', '1d']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedInterval = v!),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
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
                    title: const Text('End'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
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
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: const Text('Use Ensemble'),
                value: _useEnsemble,
                onChanged: (v) => setState(() => _useEnsemble = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _strategy,
                decoration: const InputDecoration(
                    labelText: 'Strategy', border: OutlineInputBorder()),
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
                      value: 'hybrid4',
                      child: Text('Hybrid 4: Breakout+DailyTrend')),
                  DropdownMenuItem(
                      value: 'hybrid5',
                      child: Text('Hybrid 5: Vol-adaptive+Cloud')),
                ],
                onChanged: (v) => setState(() => _strategy = v ?? 'ensemble'),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Initial Capital (USDT)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                controller:
                    TextEditingController(text: _initialCapital.toString()),
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null) _initialCapital = val;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Position Size (fraction, e.g. 0.1 = 10%)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                controller:
                    TextEditingController(text: _positionSize.toString()),
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null) _positionSize = val.clamp(0.01, 1.0);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _runBacktest,
                icon: _isRunning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: Text(_isRunning ? 'Running...' : 'Run Backtest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rezultate Backtest',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildResultRow(
                'Capital Initial', '\$${r.initialCapital.toStringAsFixed(2)}'),
            _buildResultRow(
                'Capital Final', '\$${r.finalCapital.toStringAsFixed(2)}'),
            _buildResultRow(
              'P&L Total',
              '\$${r.totalPnl.toStringAsFixed(2)} (${r.returnPercent.toStringAsFixed(2)}%)',
              valueColor: pnlColor,
            ),
            const Divider(),
            _buildResultRow('Total Trades', '${r.totalTrades}'),
            _buildResultRow('Winning Trades', '${r.winningTrades}'),
            _buildResultRow('Losing Trades', '${r.losingTrades}'),
            _buildResultRow('Win Rate', '${winRate.toStringAsFixed(1)}%'),
            const Divider(),
            _buildResultRow('Avg Win', '\$${r.avgWin.toStringAsFixed(2)}'),
            _buildResultRow('Avg Loss', '\$${r.avgLoss.toStringAsFixed(2)}'),
            _buildResultRow(
                'Max Drawdown', '${r.maxDrawdown.toStringAsFixed(2)}%',
                valueColor: Colors.red),
            const Divider(),
            _buildResultRow('Sharpe Ratio', r.sharpeRatio.toStringAsFixed(2)),
            _buildResultRow('Fees Paid', '\$${r.totalFees.toStringAsFixed(2)}'),
            const Divider(),
            _buildResultRow('Merit Score', merit.toStringAsFixed(2)),
            _buildResultRow('Decision', decision),
            if (merit > 8.0 && _strategy != 'ensemble') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
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
                icon:
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Set as Default Strategy',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
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
        report = BacktestReport(
          initialCapital: oldResult.initialCapital,
          finalCapital: oldResult.finalCapital,
          totalReturn: oldResult.totalReturn,
          numTrades: oldResult.numTrades,
          winningTrades: oldResult.winningTrades,
          losingTrades: oldResult.losingTrades,
          avgWin: oldResult.avgWin,
          avgLoss: oldResult.avgLoss,
          maxDrawdown: oldResult.maxDrawdown,
          sharpe: oldResult.sharpe,
          feesPaid: oldResult.feesPaid,
          times: oldResult.times,
          equity: oldResult.equity,
          trades: const [],
        );
      }

      setState(() {
        _rawResult = bt.BacktestResult(
          start: report.times.isEmpty ? DateTime.now() : report.times.first,
          end: report.times.isEmpty ? DateTime.now() : report.times.last,
          symbol: _selectedSymbol,
          interval: _selectedInterval,
          times: report.times,
          equity: report.equity,
          initialCapital: report.initialCapital,
          finalCapital: report.finalCapital,
          totalReturn: report.totalReturn,
          numTrades: report.numTrades,
          winningTrades: report.winningTrades,
          losingTrades: report.losingTrades,
          avgWin: report.avgWin,
          avgLoss: report.avgLoss,
          maxDrawdown: report.maxDrawdown,
          sharpe: report.sharpe,
          feesPaid: report.feesPaid,
          trades: const [],
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
