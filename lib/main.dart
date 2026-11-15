import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BazarApp());
}

class BazarApp extends StatelessWidget {
  const BazarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'বাজারের তালিকা',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const BazarScreen(),
    );
  }
}

class Item {
  String name;
  double qty;
  String unit;
  double price;
  bool done;

  Item(this.name, this.qty, this.unit, this.price, [this.done = false]);

  double get total => price * qty;

  Map<String, dynamic> toJson() => {
        'n': name,
        'q': qty,
        'u': unit,
        'p': price,
        'd': done,
      };

  factory Item.fromJson(Map<String, dynamic> m) {
    return Item(
      m['n'] as String,
      (m['q'] as num).toDouble(),
      (m['u'] ?? '') as String,
      (m['p'] as num).toDouble(),
      m['d'] as bool,
    );
  }
}

String bnStr(String s) {
  const d = '০১২৩৪৫৬৭৮৯';
  return s.replaceAllMapped(RegExp(r'[0-9]'), (m) => d[int.parse(m[0]!)]);
}

// বাংলা বা ইংরেজি সংখ্যা লিখলেও বোঝার জন্য
String toAscii(String s) {
  const d = '০১২৩৪৫৬৭৮৯';
  var r = s;
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(d[i], i.toString());
  }
  return r.replaceAll(',', '').trim();
}

String raw(double v) {
  var s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

String fmt(double v) => bnStr(raw(v));

class BazarScreen extends StatefulWidget {
  const BazarScreen({super.key});

  @override
  State<BazarScreen> createState() => _BazarScreenState();
}

class _BazarScreenState extends State<BazarScreen> {
  SharedPreferences? prefs;
  List<Item> items = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    final s = prefs?.getString('bazar-items');
    var list = <Item>[];
    if (s != null) {
      try {
        list = (jsonDecode(s) as List)
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    setState(() {
      items = list;
      loaded = true;
    });
  }

  void _save() {
    prefs?.setString(
      'bazar-items',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _editItem([Item? item]) async {
    final nameC = TextEditingController(text: item?.name ?? '');
    final qtyC = TextEditingController(text: item == null ? '1' : raw(item.qty));
    final unitC = TextEditingController(text: item?.unit ?? '');
    final priceC = TextEditingController(
      text: (item == null || item.price == 0) ? '' : raw(item.price),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'নতুন জিনিস' : 'বদলান'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                autofocus: item == null,
                decoration: const InputDecoration(labelText: 'কী কিনবেন'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyC,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'পরিমাণ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitC,
                      decoration: const InputDecoration(
                        labelText: 'একক',
                        hintText: 'কেজি, পিস',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: priceC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'একক দাম (৳)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim();
    if (name.isEmpty) return;
    final qty = double.tryParse(toAscii(qtyC.text)) ?? 1;
    final price = double.tryParse(toAscii(priceC.text)) ?? 0;
    final unit = unitC.text.trim();
    setState(() {
      if (item == null) {
        items.add(Item(name, qty, unit, price));
      } else {
        item.name = name;
        item.qty = qty;
        item.unit = unit;
        item.price = price;
      }
    });
    _save();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('সব মুছবেন?'),
        content: const Text('পুরো তালিকা মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        items.clear();
      });
      _save();
    }
  }

  Widget _sum(String label, double v, Color? color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          '৳${fmt(v)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = items.fold<double>(0, (s, e) => s + e.total);
    final bought =
        items.where((e) => e.done).fold<double>(0, (s, e) => s + e.total);
    final left = total - bought;
    final view = [
      ...items.where((e) => !e.done),
      ...items.where((e) => e.done),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('বাজারের তালিকা'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'bought') {
                setState(() {
                  items.removeWhere((e) => e.done);
                });
                _save();
              } else if (v == 'all') {
                _clearAll();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'bought', child: Text('কেনা হয়েছে এমন মুছুন')),
              PopupMenuItem(value: 'all', child: Text('সব মুছুন')),
            ],
          ),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'তালিকা খালি।\nনিচের "যোগ করুন" বোতামে ট্যাপ করে জিনিস যোগ করুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 90),
                  itemCount: view.length,
                  itemBuilder: (context, i) {
                    final item = view[i];
                    final unitText = item.unit.isEmpty ? '' : ' ${item.unit}';
                    final sub = item.price > 0
                        ? '${fmt(item.qty)}$unitText × ৳${fmt(item.price)}'
                        : '${fmt(item.qty)}$unitText';
                    return Dismissible(
                      key: ObjectKey(item),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        final idx = items.indexOf(item);
                        setState(() {
                          items.remove(item);
                        });
                        _save();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${item.name}" মুছে ফেলা হয়েছে'),
                            action: SnackBarAction(
                              label: 'ফিরিয়ে আনুন',
                              onPressed: () {
                                final at = idx > items.length ? items.length : idx;
                                setState(() {
                                  items.insert(at, item);
                                });
                                _save();
                              },
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: item.done,
                            onChanged: (v) {
                              setState(() {
                                item.done = v ?? false;
                              });
                              _save();
                            },
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 17,
                              decoration:
                                  item.done ? TextDecoration.lineThrough : null,
                              color: item.done ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(sub),
                          trailing: Text(
                            '৳${fmt(item.total)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _editItem(item),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(),
        icon: const Icon(Icons.add),
        label: const Text('যোগ করুন'),
      ),
      bottomNavigationBar: Container(
        color: cs.primaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sum('মোট', total, null),
              _sum('কেনা হয়েছে', bought, Colors.green.shade800),
              _sum('বাকি', left, Colors.red.shade700),
            ],
          ),
        ),
      ),
    );
  }
}
