import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/grid_bot.dart';

/// Ecran pentru crearea unui Grid Bot nou
class CreateGridBotScreen extends StatefulWidget {
  final String symbol;
  final double? currentPrice;
  
  const CreateGridBotScreen({
    super.key,
    required this.symbol,
    this.currentPrice,
  });

  @override
  State<CreateGridBotScreen> createState() => _CreateGridBotScreenState();
}

class _CreateGridBotScreenState extends State<CreateGridBotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _gridCountCtrl = TextEditingController(text: '120');
  final _investmentCtrl = TextEditingController(text: '50');
  
  GridMode _mode = GridMode.geometric;
  bool _autoRestart = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.currentPrice != null) {
      final price = widget.currentPrice!;
      _minPriceCtrl.text = (price * 0.9).toStringAsFixed(4);
      _maxPriceCtrl.text = (price * 1.1).toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _gridCountCtrl.dispose();
    _investmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creează Grid Bot'),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Symbol header
            Text(
              widget.symbol,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Grilă Spot',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            
            const SizedBox(height: 24),
            
            // Ce este grila Spot section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: const Text('Ce este grila Spot'),
                leading: const Icon(Icons.help_outline, color: Colors.blue),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeatureTile(
                          icon: Icons.autorenew,
                          title: 'Automatizare',
                          subtitle: 'Economisește timp prin automatizarea ordinelor de cumpărare și vânzare.',
                        ),
                        const SizedBox(height: 12),
                        _FeatureTile(
                          icon: Icons.trending_up,
                          title: 'Profit din volatilitate',
                          subtitle: 'Valorifică micile fluctuații de preț.',
                        ),
                        const SizedBox(height: 12),
                        _FeatureTile(
                          icon: Icons.schedule,
                          title: 'Strategie consecventă',
                          subtitle: 'Menține o abordare de tranzacționare constantă.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '* Deoarece condițiile de piață diferă, acești parametri nu pot garanta obținerea acelorași rezultate.',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Price Range
            const Text('Interval de preț', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preț minim',
                      border: OutlineInputBorder(),
                      suffixText: 'ETH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preț maxim',
                      border: OutlineInputBorder(),
                      suffixText: 'ETH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Invalid';
                      final min = double.tryParse(_minPriceCtrl.text) ?? 0;
                      if (val <= min) return 'Must be > min';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Grid Count
            const Text('Numărul de grile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gridCountCtrl,
              decoration: const InputDecoration(
                labelText: 'Grile',
                border: OutlineInputBorder(),
                helperText: '2-200 grile recomandate',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final val = int.tryParse(v ?? '');
                if (val == null || val < 2 || val > 200) return '2-200';
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Mode
            const Text('Mod', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SegmentedButton<GridMode>(
              segments: const [
                ButtonSegment(
                  value: GridMode.arithmetic,
                  label: Text('Aritmetic'),
                  icon: Icon(Icons.linear_scale),
                ),
                ButtonSegment(
                  value: GridMode.geometric,
                  label: Text('Geometric'),
                  icon: Icon(Icons.show_chart),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<GridMode> newSelection) {
                setState(() => _mode = newSelection.first);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Investment
            const Text('Investiție', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _investmentCtrl,
              decoration: const InputDecoration(
                labelText: 'Sumă',
                border: OutlineInputBorder(),
                suffixText: 'USDT',
                helperText: 'Minim 10 USDT',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val < 10) return 'Min 10 USDT';
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Auto-restart toggle
            SwitchListTile(
              title: const Text('Auto-restart la finalizare'),
              subtitle: const Text('Botul va reporni automat când toate grilele sunt completate'),
              value: _autoRestart,
              onChanged: (v) => setState(() => _autoRestart = v),
            ),
            
            const SizedBox(height: 24),
            
            // Profit estimate
            if (_formKey.currentState?.validate() ?? false)
              Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimare profit', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Profit/grilă: ${_calculateProfitPerGrid().toStringAsFixed(2)} %',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Create button
            ElevatedButton(
              onPressed: _createBot,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Creează Bot', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProfitPerGrid() {
    final min = double.tryParse(_minPriceCtrl.text) ?? 0;
    final max = double.tryParse(_maxPriceCtrl.text) ?? 0;
    final grids = int.tryParse(_gridCountCtrl.text) ?? 1;
    if (min <= 0 || max <= min || grids < 2) return 0;
    final step = (max - min) / grids;
    return (step / min) * 100;
  }

  void _createBot() {
    if (!_formKey.currentState!.validate()) return;
    
    final config = GridBotConfig(
      symbol: widget.symbol,
      minPrice: double.parse(_minPriceCtrl.text),
      maxPrice: double.parse(_maxPriceCtrl.text),
      gridCount: int.parse(_gridCountCtrl.text),
      investment: double.parse(_investmentCtrl.text),
      mode: _mode,
      autoRestart: _autoRestart,
    );
    
    if (!config.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.validationError ?? 'Invalid configuration')),
      );
      return;
    }
    
    // TODO: Create bot via service
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bot creat cu succes!')),
    );
    Navigator.pop(context, config);
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

