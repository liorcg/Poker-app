import 'package:flutter_test/flutter_test.dart';
import 'package:poker_app/settlement.dart';

void main() {
  test('one loser pays two winners', () {
    final t = settle({'Dan': -100, 'Noa': 60, 'Lior': 40});
    expect(t.map((e) => e.toString()).toList(),
        ['Dan pays Noa 60', 'Dan pays Lior 40']);
  });

  test('two losers, one winner', () {
    final t = settle({'A': -30, 'B': -70, 'C': 100});
    expect(t.map((e) => e.toString()).toList(),
        ['B pays C 70', 'A pays C 30']);
  });

  test('everyone even means no payments', () {
    expect(settle({'A': 0, 'B': 0}), isEmpty);
  });
}
