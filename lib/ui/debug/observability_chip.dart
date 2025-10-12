import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ObservabilityChip extends StatefulWidget {
  final int maxItems;
  const ObservabilityChip({super.key, this.maxItems = 3});

  @override
  State<ObservabilityChip> createState() => _ObservabilityChipState();
}

class _ObservabilityChipState extends State<ObservabilityChip> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTraces();
  }

  Future<List<Map<String, dynamic>>> _loadTraces() async {
    if (kIsWeb) {
      // On web we used an in-memory sink that isn't globally accessible.
      // Show a helpful message instead of failing.
      return [
        {
          'ts': DateTime.now().toUtc().toIso8601String(),
          'symbol': 'N/A (web)',
          'modelRev': 'N/A',
          'pBuy': null,
          'expReturn': null,
          'annVol': null,
          'meta': {
            'note':
                'Tracing uses in-memory sink on Web. Run on device/simulator to get JSONL file.'
          }
        }
      ];
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/prediction_traces.jsonl');
    if (!await file.exists()) return [];

    // Simple approach: read all lines, take last N (file is small in practice).
    final lines = await file.readAsLines();
    final last = lines.reversed.take(widget.maxItems).toList().reversed;
    final List<Map<String, dynamic>> items = [];
    for (final line in last) {
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        items.add(m);
      } catch (_) {
        // skip malformed lines
      }
    }
    return items;
  }

  Future<void> _clearLogs() async {
    if (kIsWeb) {
      setState(() => _future = _loadTraces());
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/prediction_traces.jsonl');
    if (await file.exists()) {
      await file.writeAsString(''); // truncate
    }
    if (mounted) setState(() => _future = _loadTraces());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ChipShell(label: 'Observability', value: 'loading…');
        }
        if (snap.hasError) {
          return _ChipShell(
            label: 'Observability',
            value: 'error',
            child: TextButton.icon(
              onPressed: () => setState(() => _future = _loadTraces()),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          );
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return _ChipShell(
            label: 'Observability',
            value: 'no logs',
            child: TextButton.icon(
              onPressed: () => setState(() => _future = _loadTraces()),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          );
        }

        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          leading: const Icon(Icons.visibility),
          title: const Text('Observability'),
          subtitle: Text('${data.length} recent trace(s)'),
          trailing: IconButton(
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_sweep),
          ),
          children: [
            for (final m in data) _TraceRow(m: m),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _future = _loadTraces()),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChipShell extends StatelessWidget {
  final String label;
  final String value;
  final Widget? child;
  const _ChipShell({required this.label, required this.value, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputChip(
          label: Text('$label: $value'),
          avatar: const Icon(Icons.visibility),
          onPressed: null,
        ),
        if (child != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: child),
      ],
    );
  }
}

class _TraceRow extends StatelessWidget {
  final Map<String, dynamic> m;
  const _TraceRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final ts = (m['ts'] ?? m['asOf'] ?? '').toString();
    final symbol = (m['symbol'] ?? '').toString();
    final modelRev = (m['modelRev'] ?? '').toString();

    final action = (m['action'] ?? '').toString().toUpperCase();
    final num? pBuy = _asNum(m['pBuy']);
    final num? expReturn = _asNum(m['expReturn']);
    final num? annVol = _asNum(m['annVol']);

    num? conf;
    if (m.containsKey('confidence')) {
      conf = _asNum(m['confidence']);
    } else if (action.isNotEmpty && pBuy != null) {
      conf = (m['probs'] is List && (m['probs'] as List).isNotEmpty)
          ? ((m['probs'] as List).cast<num>().reduce((a, b) => a > b ? a : b))
          : (pBuy >= 0.5 ? pBuy : (1 - pBuy));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
            '$symbol • ${action.isEmpty ? '—' : action} • ${(conf == null ? '—' : (conf * 100).toStringAsFixed(1))}%'),
        subtitle: Text(
            'ts: $ts\nrev: $modelRev\nr: ${_pct(expReturn)}  vol: ${_pct(annVol)}'),
        trailing: const Icon(Icons.info_outline),
      ),
    );
  }

  String _pct(num? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(2)}%';
  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}
