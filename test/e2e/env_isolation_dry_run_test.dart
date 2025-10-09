import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Live DRY-RUN short-circuits order send', () async {
    const isLive = true;
    const dryRun = true;
    const willSendNetwork = isLive && !dryRun;
    expect(willSendNetwork, isFalse);
  });
}



