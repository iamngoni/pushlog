import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/weight_math.dart';

void main() {
  test('72.5 kg stores 72500 grams and displays 72.5', () {
    expect(kilogramsToGrams(72.5), 72500);
    expect(gramsToDisplay(72500, WeightUnit.kg), 72.5);
  });

  test('160.0 lb stores 72575 grams and displays 160.0', () {
    expect(poundsToGrams(160), 72575);
    expect(gramsToDisplay(72575, WeightUnit.lb), 160.0);
  });

  test('share latest clears when progress sharing turns off', () {
    const settings = WeightSettings(
      shareProgress: true,
      shareLatestWeight: true,
    );
    final next = settings.copyWith(shareProgress: false);
    expect(next.shareLatestWeight, isFalse);
  });
}
