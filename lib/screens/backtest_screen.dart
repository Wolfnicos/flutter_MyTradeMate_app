import 'package:flutter/material.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:intl/intl.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final List<String> _symbols = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT'];
  String _selectedSymbol = 'BTCUSDT';
  String _selectedInterval = '1h';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  double _initialCapital = 10000.0;
  double _positionSize = 0.1; // 10% of capital per trade
  
  bool _isRunning = false;
  BacktestResult? _result;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backtesting & Simulation'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configurare Backtest',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Symbol selector
                    DropdownButtonFormField<String>(
                      value: _selectedSymbol,
                      decoration: const InputDecoration(
                        labelText: 'Symbol',
                        border: OutlineInputBorder(),
                      ),
                      items: _symbols.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedSymbol = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    // Interval selector
                    DropdownButtonFormField<String>(
                      value: _selectedInterval,
                      decoration: const InputDecoration(
                        labelText: 'Interval',
                        border: OutlineInputBorder(),
                      ),
                      items: ['5m', '15m', '1h', '4h', '1d'].map((s) => 
                        DropdownMenuItem(value: s, child: Text(s))
                      ).toList(),
                      onChanged: (v) => setState(() => _selectedInterval = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    // Date range
                    Row(
                      children: [
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
                              if (date != null) {
                                setState(() => _startDate = date);
                              }
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
                              if (date != null) {
                                setState(() => _endDate = date);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Initial capital
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Initial Capital (USDT)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _initialCapital.toString()
                      ),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) _initialCapital = val;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Position size
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Position Size (fraction, e.g. 0.1 = 10%)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _positionSize.toString()
                      ),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) _positionSize = val.clamp(0.01, 1.0);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Run Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runBacktest,
              icon: _isRunning 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
            
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResultsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final r = _result!;
    final pnlColor = r.totalPnl >= 0 ? Colors.green : Colors.red;
    final winRate = r.totalTrades > 0 ? (r.winningTrades / r.totalTrades) * 100 : 0.0;
    
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
            
            _buildResultRow('Capital Initial', '\$${r.initialCapital.toStringAsFixed(2)}'),
            _buildResultRow('Capital Final', '\$${r.finalCapital.toStringAsFixed(2)}'),
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
            _buildResultRow('Max Drawdown', '${r.maxDrawdown.toStringAsFixed(2)}%', valueColor: Colors.red),
            const Divider(),
            _buildResultRow('Sharpe Ratio', r.sharpeRatio.toStringAsFixed(2)),
            _buildResultRow('Fees Paid', '\$${r.totalFees.toStringAsFixed(2)}'),
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
      final client = await DioBinanceClient.createFromPrefs();
      final aiService = AIService();
      
      // Fetch historical klines
      final klines = await client.klines(
        _selectedSymbol,
        _selectedInterval,
        limit: 1000,
      );
      
      if (klines.isEmpty) {
        throw Exception('No historical data available');
      }
      
      // Run backtest simulation
      double capital = _initialCapital;
      double position = 0.0; // BTC/ETH/etc amount held
      double entryPrice = 0.0;
      int totalTrades = 0;
      int winningTrades = 0;
      int losingTrades = 0;
      double totalWinAmount = 0.0;
      double totalLossAmount = 0.0;
      double totalFees = 0.0;
      double maxCapital = _initialCapital;
      double minCapital = _initialCapital;
      final List<double> returns = [];
      
      for (int i = 64; i < klines.length; i++) {
        final candle = klines[i];
        final closePrice = candle[4].toDouble();
        
        // Get AI prediction (simplified - in real implementation you'd use actual sequence)
        try {
          final prediction = await aiService.getPrediction(_selectedSymbol);
          
          // Trading logic
          if (position == 0 && prediction.action == 'BUY' && prediction.confidence >= 60) {
            // Enter long position
            final investAmount = capital * _positionSize;
            final fee = investAmount * 0.001; // 0.1% fee
            position = (investAmount - fee) / closePrice;
            capital -= investAmount;
            totalFees += fee;
            entryPrice = closePrice;
            totalTrades++;
          } else if (position > 0 && (prediction.action == 'SELL' || prediction.confidence < 40)) {
            // Exit position
            final sellAmount = position * closePrice;
            final fee = sellAmount * 0.001;
            capital += (sellAmount - fee);
            totalFees += fee;
            
            final pnl = sellAmount - (position * entryPrice);
            if (pnl > 0) {
              winningTrades++;
              totalWinAmount += pnl;
            } else {
              losingTrades++;
              totalLossAmount += pnl.abs();
            }
            
            position = 0.0;
          }
          
          // Track drawdown
          final currentCapital = capital + (position * closePrice);
          if (currentCapital > maxCapital) maxCapital = currentCapital;
          if (currentCapital < minCapital) minCapital = currentCapital;
          
          // Track returns
          if (i > 64) {
            final prevClose = klines[i - 1][4].toDouble();
            final ret = (closePrice - prevClose) / prevClose;
            returns.add(ret);
          }
        } catch (e) {
          // Skip this candle if prediction fails
          continue;
        }
      }
      
      // Close any remaining position
      if (position > 0) {
        final lastPrice = klines.last[4].toDouble();
        final sellAmount = position * lastPrice;
        final fee = sellAmount * 0.001;
        capital += (sellAmount - fee);
        totalFees += fee;
        
        final pnl = sellAmount - (position * entryPrice);
        if (pnl > 0) {
          winningTrades++;
          totalWinAmount += pnl;
        } else {
          losingTrades++;
          totalLossAmount += pnl.abs();
        }
      }
      
      final finalCapital = capital;
      final totalPnl = finalCapital - _initialCapital;
      final returnPercent = (totalPnl / _initialCapital) * 100;
      final maxDrawdown = ((maxCapital - minCapital) / maxCapital) * 100;
      
      // Calculate Sharpe ratio (simplified)
      double sharpeRatio = 0.0;
      if (returns.isNotEmpty) {
        final avgReturn = returns.reduce((a, b) => a + b) / returns.length;
        final variance = returns.map((r) => (r - avgReturn) * (r - avgReturn)).reduce((a, b) => a + b) / returns.length;
        final stdDev = variance > 0 ? variance : 0.01;
        sharpeRatio = avgReturn / stdDev;
      }
      
      setState(() {
        _result = BacktestResult(
          initialCapital: _initialCapital,
          finalCapital: finalCapital,
          totalPnl: totalPnl,
          returnPercent: returnPercent,
          totalTrades: totalTrades,
          winningTrades: winningTrades,
          losingTrades: losingTrades,
          avgWin: winningTrades > 0 ? totalWinAmount / winningTrades : 0.0,
          avgLoss: losingTrades > 0 ? totalLossAmount / losingTrades : 0.0,
          maxDrawdown: maxDrawdown,
          sharpeRatio: sharpeRatio,
          totalFees: totalFees,
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
