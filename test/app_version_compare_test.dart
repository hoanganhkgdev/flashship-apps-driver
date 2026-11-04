import 'package:flashship_driver/features/version/providers/app_version_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mức yêu cầu không ghi build: chỉ so tên phiên bản', () {
    expect(isVersionOlder('10.0.22+124', '10.0.23'), isTrue);
    expect(isVersionOlder('10.0.23+125', '10.0.23'), isFalse);
    expect(isVersionOlder('10.0.23+1', '10.0.22'), isFalse);
  });

  test('mức yêu cầu có build: ép được bản cùng tên nhưng build cũ', () {
    expect(isVersionOlder('10.0.23+125', '10.0.23+126'), isTrue);
    expect(isVersionOlder('10.0.23+126', '10.0.23+126'), isFalse);
    expect(isVersionOlder('10.0.24+1', '10.0.23+126'), isFalse);
  });
}
