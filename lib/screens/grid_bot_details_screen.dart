import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/grid_bot.dart';

/// Ecran detalii bot (conform screenshot-ului Binance 2025)
class GridBotDetailsScreen extends StatefulWidget {
  final GridBot bot;

  const GridBotDetailsScreen({super.key, required this.bot});

  @override
  State<GridBotDetailsScreen> createState() => _GridBotDetailsScreenState();
}

class _GridBotDetailsScreenState extends State<GridBotDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final bot = widget.bot;
    final stats = bot.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalii bot'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showBotMenu(context),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header: Symbol & Status
          Row(
            children: [
              Text(
                bot.symbol,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              _StatusChip(status: bot.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Grilă Spot  ${bot.gridCount}',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),

          const SizedBox(height: 24),

          // Profitability Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profituri istorice',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'ROI',
                          value: '${stats.roi.toStringAsFixed(2)} %',
                          valueColor:
                              stats.roi >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _StatTile(
                          label: 'PNL (USD)',
                          value: '+\$${stats.pnlUsd.toStringAsFixed(2)}',
                          valueColor:
                              stats.pnlUsd >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // PNL Chart
                  SizedBox(
                    height: 180,
                    child: _buildPnlChart(stats),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Previzualizare bot Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Previzualizare bot',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  // Timeframe selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      '4 h',
                      '6 h',
                      '8 h',
                      '12 h',
                      '1 z',
                      '3 z',
                      '1 s',
                      '1 L'
                    ]
                        .map((tf) => _TimeframeChip(
                              label: tf,
                              selected: tf == '1 s',
                              onTap: () {},
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Bollinger Bands indicators
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BollingerIndicator(label: 'BOLL:(20, 2)', value: ''),
                      _BollingerIndicator(
                          label: 'UP:', value: '0.2896', color: Colors.orange),
                      _BollingerIndicator(
                          label: 'MB:', value: '0.2302', color: Colors.yellow),
                      _BollingerIndicator(
                          label: 'DN:', value: '0.1707', color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Price chart with grid levels
                  SizedBox(
                    height: 200,
                    child: _buildGridPreviewChart(bot),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Informații de bază Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informații de bază',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _InfoRow(
                      label: 'Durată de executare',
                      value: _formatDuration(stats.executionTime)),
                  _InfoRow(
                      label: '24H/Total tranzacții asociate',
                      value:
                          '${stats.transactions24h}/${stats.totalTransactions}'),
                  _InfoRow(
                      label: 'Interval de preț (ETH)',
                      value:
                          '${bot.minPrice.toStringAsFixed(4)} - ${bot.maxPrice.toStringAsFixed(4)}'),
                  _InfoRow(
                      label: 'Numărul de grile', value: '${bot.gridCount}'),
                  _InfoRow(
                      label: 'Mod',
                      value: bot.stats.executionTime.inHours > 0
                          ? 'Geometric'
                          : 'Arithmetic'),
                  _InfoRow(
                      label: 'Profit/grilă (taxe deduse)',
                      value: '${bot.profitPerGrid.toStringAsFixed(2)} %',
                      valueColor: Colors.green),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pauseBot(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(bot.status == GridBotStatus.running
                      ? 'Pauză'
                      : 'Reluare'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _stopBot(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Oprește bot'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPnlChart(GridBotStats stats) {
    // Simulăm date istorice PNL
    final spots = List.generate(20, (i) {
      final progress = i / 19;
      final pnl = stats.pnlUsd * progress + (i % 3 - 1) * 500; // cu variație
      return FlSpot(i.toDouble(), pnl);
    });

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.withValues(alpha: 77),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridPreviewChart(GridBot bot) {
    // Chart cu niveluri de grilă și candlestick
    final spots = List.generate(50, (i) {
      final base = (bot.minPrice + bot.maxPrice) / 2;
      final range = bot.priceRange / 4;
      return FlSpot(i.toDouble(), base + range * (i % 10 - 5) / 5);
    });

    return LineChart(
      LineChartData(
        minY: bot.minPrice * 0.95,
        maxY: bot.maxPrice * 1.05,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: bot.gridStep,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.pink.withValues(alpha: 77),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.cyan,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Highest price marker
            HorizontalLine(
              y: bot.maxPrice,
              color: Colors.red,
              strokeWidth: 2,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(color: Colors.red, fontSize: 10),
                labelResolver: (line) => 'Cel mai mare preț',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0)
      return '${d.inDays}z ${d.inHours % 24}h ${d.inMinutes % 60}m';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  void _showBotMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editează parametri'),
            onTap: () {
              Navigator.pop(ctx);
              // TODO: navigate to edit screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Istoric tranzacții'),
            onTap: () {
              Navigator.pop(ctx);
              // TODO: show transactions
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Partajează'),
            onTap: () {
              Navigator.pop(ctx);
              // TODO: share bot config
            },
          ),
        ],
      ),
    );
  }

  void _pauseBot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.bot.status == GridBotStatus.running
            ? 'Bot pus în pauză'
            : 'Bot reluat'),
      ),
    );
    // TODO: implement pause/resume logic
  }

  void _stopBot(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oprește bot?'),
        content: const Text(
          'Toate ordinele deschise vor fi anulate și poziția va fi închisă la prețul curent de piață.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // close details screen
              // TODO: implement stop logic
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oprește'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GridBotStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case GridBotStatus.running:
        color = Colors.green;
        label = 'Activ';
        break;
      case GridBotStatus.paused:
        color = Colors.orange;
        label = 'Pauză';
        break;
      case GridBotStatus.stopped:
        color = Colors.grey;
        label = 'Oprit';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 51),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeframeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeframeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber.withValues(alpha: 77)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? Colors.amber : Colors.grey.withValues(alpha: 77),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.amber : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _BollingerIndicator extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BollingerIndicator({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (value.isNotEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
      ],
    );
  }
}
