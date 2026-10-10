import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settlement.dart';

void main() => runApp(const PokerApp());

class PokerApp extends StatelessWidget {
  const PokerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Night',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E3A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class Player {
  String name;
  int buyIn;
  int? cashOut;

  /// Money the player has overall, updated after every settle up.
  int balance;

  Player(this.name, {this.buyIn = 0, this.cashOut, this.balance = 0});

  Map<String, dynamic> toJson() =>
      {'name': name, 'buyIn': buyIn, 'cashOut': cashOut, 'balance': balance};

  factory Player.fromJson(Map<String, dynamic> j, {int startingMoney = 0}) =>
      Player(j['name'] as String,
          buyIn: j['buyIn'] as int,
          cashOut: j['cashOut'] as int?,
          balance: j['balance'] as int? ?? startingMoney);
}

const _storeKey = 'game_v1';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final List<Player> _players = [];
  int _defaultBuyIn = 100;
  int _startingMoney = 1000;
  int _round = 1;

  int get _pot => _players.fold(0, (s, p) => s + p.buyIn);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _defaultBuyIn = data['defaultBuyIn'] as int? ?? 100;
      _startingMoney = data['startingMoney'] as int? ?? 1000;
      _round = data['round'] as int? ?? 1;
      _players
        ..clear()
        ..addAll((data['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>,
                startingMoney: _startingMoney)));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storeKey,
        jsonEncode({
          'defaultBuyIn': _defaultBuyIn,
          'startingMoney': _startingMoney,
          'round': _round,
          'players': _players.map((p) => p.toJson()).toList(),
        }));
  }

  void _update(VoidCallback change) {
    setState(change);
    _save();
  }

  Future<int?> _askAmount(String title, {int? initial}) async {
    final ctrl = TextEditingController(text: initial?.toString() ?? '');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _addPlayer() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Add')),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    if (_players.any((p) => p.name == trimmed)) {
      _snack('$trimmed is already in the game');
      return;
    }
    _update(() => _players.add(Player(trimmed,
        buyIn: _defaultBuyIn, balance: _startingMoney)));
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _playerMenu(Player p) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(p.name, style: const TextStyle(fontSize: 20))),
          ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Custom buy-in'),
              onTap: () => Navigator.pop(ctx, 'custom')),
          ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Fix total buy-in'),
              onTap: () => Navigator.pop(ctx, 'fix')),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove player'),
              onTap: () => Navigator.pop(ctx, 'remove')),
        ]),
      ),
    );
    if (choice == 'custom') {
      final a = await _askAmount('Buy-in for ${p.name}');
      if (a != null && a > 0) _update(() => p.buyIn += a);
    } else if (choice == 'fix') {
      final a = await _askAmount('Total buy-in for ${p.name}', initial: p.buyIn);
      if (a != null) _update(() => p.buyIn = a);
    } else if (choice == 'remove') {
      _update(() => _players.remove(p));
    }
  }

  Future<void> _settingsAction(String action) async {
    if (action == 'buyin') {
      final a = await _askAmount('Default buy-in', initial: _defaultBuyIn);
      if (a != null && a > 0) _update(() => _defaultBuyIn = a);
    } else if (action == 'start') {
      final a = await _askAmount('Starting money for new players',
          initial: _startingMoney);
      if (a != null && a > 0) _update(() => _startingMoney = a);
    } else if (action == 'reset') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset everyone\'s money?'),
          content: Text('Every player goes back to $_startingMoney.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reset')),
          ],
        ),
      );
      if (ok == true) {
        _update(() {
          for (final p in _players) {
            p.balance = _startingMoney;
          }
        });
      }
    }
  }

  /// Adds each player's win or loss to their money and starts the next round.
  void _finishRound() {
    _update(() {
      for (final p in _players) {
        p.balance += (p.cashOut ?? p.buyIn) - p.buyIn;
        p.buyIn = _defaultBuyIn;
        p.cashOut = null;
      }
      _round++;
    });
  }

  Future<void> _newGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('Keep the same players and reset all amounts?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Clear players too')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keep players')),
        ],
      ),
    );
    if (ok == null) return;
    _update(() {
      _round = 1;
      if (ok) {
        for (final p in _players) {
          p.buyIn = _defaultBuyIn;
          p.cashOut = null;
        }
      } else {
        _players.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Night'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected: _settingsAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'buyin', child: Text('Default buy-in')),
              PopupMenuItem(value: 'start', child: Text('Starting money')),
              PopupMenuItem(
                  value: 'reset', child: Text('Reset everyone\'s money')),
            ],
          ),
          IconButton(
              tooltip: 'New game',
              icon: const Icon(Icons.refresh),
              onPressed: _newGame),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text('Round $_round',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer)),
            Text('Total in the pot',
                style: TextStyle(color: scheme.onPrimaryContainer)),
            Text('$_pot',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer)),
            Text('${_players.length} players · buy-in $_defaultBuyIn',
                style: TextStyle(color: scheme.onPrimaryContainer)),
          ]),
        ),
        Expanded(
          child: _players.isEmpty
              ? const Center(
                  child: Text('Tap "Add player" to start',
                      style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: _players.length,
                  itemBuilder: (ctx, i) {
                    final p = _players[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        onTap: () => _playerMenu(p),
                        leading: CircleAvatar(
                            child: Text(p.name.characters.first.toUpperCase())),
                        title: Text(p.name,
                            style: const TextStyle(fontSize: 18)),
                        subtitle: Text('Money: ${p.balance}   In: ${p.buyIn}'),
                        trailing: FilledButton.tonal(
                          onPressed: () =>
                              _update(() => p.buyIn += _defaultBuyIn),
                          child: Text('+$_defaultBuyIn'),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add player'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _players.length < 2
                      ? null
                      : () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SettleScreen(
                                      players: _players,
                                      round: _round,
                                      onChanged: _save,
                                      onFinish: _finishRound)));
                          setState(() {});
                        },
                  icon: const Icon(Icons.payments),
                  label: const Text('Settle up'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class SettleScreen extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onChanged;
  final VoidCallback onFinish;
  final int round;

  const SettleScreen(
      {super.key,
      required this.players,
      required this.round,
      required this.onChanged,
      required this.onFinish});

  @override
  State<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends State<SettleScreen> {
  late final Map<Player, TextEditingController> _ctrls = {
    for (final p in widget.players)
      p: TextEditingController(text: p.cashOut?.toString() ?? '')
  };

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final players = widget.players;
    final pot = players.fold(0, (s, p) => s + p.buyIn);
    final allEntered = players.every((p) => p.cashOut != null);
    final counted = players.fold(0, (s, p) => s + (p.cashOut ?? 0));
    final diff = counted - pot;
    final transfers = allEntered && diff == 0
        ? settle({for (final p in players) p.name: p.cashOut! - p.buyIn})
        : <Transfer>[];

    return Scaffold(
      appBar: AppBar(title: Text('Settle up · Round ${widget.round}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Tap Win for the player who took the whole pot, '
            'or enter how many chips each player has at the end.',
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        for (final p in players)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 18)),
                      Text('Money: ${p.balance}   In: ${p.buyIn}'
                          '${p.cashOut == null ? '' : '   Net: ${_signed(p.cashOut! - p.buyIn)}'}'),
                    ]),
              ),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ctrls[p],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Chips out', border: OutlineInputBorder()),
                  onChanged: (v) {
                    setState(() => p.cashOut = int.tryParse(v));
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _win(p),
                child: const Text('Win'),
              ),
            ]),
          ),
        const SizedBox(height: 16),
        if (!allEntered)
          const Text('Waiting for every player\'s chip count.')
        else if (diff != 0)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chips don\'t match the pot. Counted $counted but $pot went in '
                '(${diff > 0 ? '$diff too many' : '${-diff} missing'}).',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          )
        else ...[
          Text('Payments', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (transfers.isEmpty) const Text('Everyone is even. Nobody pays.'),
          for (final t in transfers)
            Card(
              child: ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: Text('${t.from} pays ${t.to}'),
                trailing: Text('${t.amount}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 16),
          Text('Money after this round',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final p in players)
            ListTile(
              dense: true,
              title: Text(p.name, style: const TextStyle(fontSize: 16)),
              subtitle: Text('${p.balance} ${_signed(p.cashOut! - p.buyIn)}'),
              trailing: Text('${p.balance + p.cashOut! - p.buyIn}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _confirmFinish(context),
            icon: const Icon(Icons.check),
            label: Text('Finish round ${widget.round} & update money'),
          ),
        ],
      ]),
    );
  }

  /// Gives the whole pot to [winner]; everyone else ends with nothing.
  void _win(Player winner) {
    final pot = widget.players.fold(0, (s, p) => s + p.buyIn);
    setState(() {
      for (final p in widget.players) {
        p.cashOut = identical(p, winner) ? pot : 0;
        _ctrls[p]!.text = '${p.cashOut}';
      }
    });
    widget.onChanged();
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Finish round ${widget.round}?'),
        content: const Text(
            'Wins are added and losses are taken from each player\'s money. '
            'Buy-ins reset for the next round.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finish')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    widget.onFinish();
    Navigator.pop(context);
  }

  String _signed(int v) => v > 0 ? '+$v' : '$v';
}
