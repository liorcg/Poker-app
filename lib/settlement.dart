/// A single payment needed to settle the game.
class Transfer {
  final String from;
  final String to;
  final int amount;

  const Transfer(this.from, this.to, this.amount);

  @override
  String toString() => '$from pays $to $amount';
}

/// Works out the fewest simple payments so everyone ends up even.
///
/// [net] maps each player to (cash out - total buy-in). Positive means the
/// player won money, negative means they lost.
List<Transfer> settle(Map<String, int> net) {
  final winners = <MapEntry<String, int>>[];
  final losers = <MapEntry<String, int>>[];
  net.forEach((name, value) {
    if (value > 0) winners.add(MapEntry(name, value));
    if (value < 0) losers.add(MapEntry(name, -value));
  });
  winners.sort((a, b) => b.value.compareTo(a.value));
  losers.sort((a, b) => b.value.compareTo(a.value));

  final result = <Transfer>[];
  var w = 0, l = 0;
  var wLeft = winners.isEmpty ? 0 : winners[0].value;
  var lLeft = losers.isEmpty ? 0 : losers[0].value;
  while (w < winners.length && l < losers.length) {
    final amount = wLeft < lLeft ? wLeft : lLeft;
    if (amount > 0) {
      result.add(Transfer(losers[l].key, winners[w].key, amount));
    }
    wLeft -= amount;
    lLeft -= amount;
    if (wLeft == 0 && ++w < winners.length) wLeft = winners[w].value;
    if (lLeft == 0 && ++l < losers.length) lLeft = losers[l].value;
  }
  return result;
}
