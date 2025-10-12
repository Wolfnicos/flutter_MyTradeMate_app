import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/trading_modal.dart';

class _MiniPlace extends StatefulWidget {
  const _MiniPlace();
  @override
  State<_MiniPlace> createState() => _MiniPlaceState();
}

class _MiniPlaceState extends State<_MiniPlace> {
  final _ctl = TextEditingController(text: '');
  num? _q;

  @override
  Widget build(BuildContext context) {
    final valid = isPlaceEnabledForTest(_q);
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: amountFieldKey,
              controller: _ctl,
              onChanged: (t) => setState(() {
                _q = num.tryParse(t);
              }),
            ),
            ElevatedButton(
              key: placeOrderBtnKey,
              onPressed: valid ? () {} : null,
              child: const Text('Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Place button disabled when amount invalid (fallback harness)',
      (tester) async {
    await tester.pumpWidget(const _MiniPlace());

    ElevatedButton btn() =>
        tester.widget<ElevatedButton>(find.byKey(placeOrderBtnKey));
    expect(btn().onPressed, isNull);

    await tester.enterText(find.byKey(amountFieldKey), '0');
    await tester.pump();
    expect(btn().onPressed, isNull);

    await tester.enterText(find.byKey(amountFieldKey), '0.01');
    await tester.pump();
    expect(btn().onPressed, isNotNull);
  });
}
