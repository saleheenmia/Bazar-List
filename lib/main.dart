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

// ডিফল্ট একক ও ড্রপডাউনের তালিকা
const String defaultUnit = 'পিস';
const String otherUnit = 'অন্যান্য';
const List<String> unitOptions = [
  'পিস',
  'কেজি',
  'গ্রাম',
  'লিটার',
  'ডজন',
  'হালি',
  'প্যাকেট',
  'আঁটি',
];

class Item {
  String name;
  double qty;
  String unit;
  double price;
  bool done;
  int created; // তৈরির সময় (millisecondsSinceEpoch), পুরনো আইটেমের জন্য 0

  Item(this.name, this.qty, this.unit, this.price,
      [this.done = false, this.created = 0]);

  double get total => price * qty;

  Map<String, dynamic> toJson() => {
        'n': name,
        'q': qty,
        'u': unit,
        'p': price,
        'd': done,
        'c': created,
      };

  factory Item.fromJson(Map<String, dynamic> m) {
    return Item(
      m['n'] as String,
      (m['q'] as num).toDouble(),
      (m['u'] ?? '') as String,
      (m['p'] as num).toDouble(),
      m['d'] as bool,
      ((m['c'] ?? 0) as num).toInt(),
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

const List<String> monthNames = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

// তারিখ ও সময়: যেমন "১৫ নভেম্বর ২০২৬, রাত ৯:৩০"
String fmtDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  String period;
  if (h >= 4 && h < 6) {
    period = 'ভোর';
  } else if (h >= 6 && h < 12) {
    period = 'সকাল';
  } else if (h >= 12 && h < 15) {
    period = 'দুপুর';
  } else if (h >= 15 && h < 17) {
    period = 'বিকাল';
  } else if (h >= 17 && h < 19) {
    period = 'সন্ধ্যা';
  } else {
    period = 'রাত';
  }
  final mm = d.minute.toString().padLeft(2, '0');
  return '${bnStr(d.day.toString())} ${monthNames[d.month - 1]} ${bnStr(d.year.toString())}, $period ${bnStr(h12.toString())}:${bnStr(mm)}';
}

class Note {
  final int id;
  String title;
  String body;
  int created;
  int updated;

  Note(this.id, this.title, this.body, this.created, this.updated);

  Map<String, dynamic> toJson() => {
        'i': id,
        't': title,
        'b': body,
        'c': created,
        'u': updated,
      };

  factory Note.fromJson(Map<String, dynamic> m) {
    return Note(
      m['i'] as int,
      m['t'] as String,
      m['b'] as String,
      m['c'] as int,
      m['u'] as int,
    );
  }
}

List<Note> loadNotes(SharedPreferences prefs) {
  final s = prefs.getString('bazar-notes');
  if (s == null) return [];
  try {
    return (jsonDecode(s) as List)
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

void saveNotes(SharedPreferences prefs, List<Note> list) {
  prefs.setString('bazar-notes', jsonEncode(list.map((e) => e.toJson()).toList()));
}

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
    final priceC = TextEditingController(
      text: (item == null || item.price == 0) ? '' : raw(item.price),
    );

    // একক: নতুন হলে ডিফল্ট "পিস"; পুরনো আইটেমের একক তালিকায় না থাকলে "অন্যান্য"-তে দেখাবে
    final customUnitC = TextEditingController();
    final startUnit =
        (item == null || item.unit.isEmpty) ? defaultUnit : item.unit;
    String selectedUnit;
    if (unitOptions.contains(startUnit)) {
      selectedUnit = startUnit;
    } else {
      selectedUnit = otherUnit;
      customUnitC.text = startUnit;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyC,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'পরিমাণ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'একক'),
                        items: [
                          ...unitOptions,
                          otherUnit,
                        ]
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() {
                            selectedUnit = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedUnit == otherUnit)
                  TextField(
                    controller: customUnitC,
                    decoration: const InputDecoration(
                      labelText: 'নিজে লিখুন',
                      hintText: 'যেমন: বস্তা, বোতল',
                    ),
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
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim();
    if (name.isEmpty) return;
    final qty = double.tryParse(toAscii(qtyC.text)) ?? 1;
    final price = double.tryParse(toAscii(priceC.text)) ?? 0;
    var unit =
        selectedUnit == otherUnit ? customUnitC.text.trim() : selectedUnit;
    if (unit.isEmpty) unit = defaultUnit;
    setState(() {
      if (item == null) {
        items.add(Item(
          name,
          qty,
          unit,
          price,
          false,
          DateTime.now().millisecondsSinceEpoch,
        ));
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

  Future<void> _newNote() async {
    final p = prefs;
    if (p == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditor(prefs: p)),
    );
  }

  Future<void> _openNotes() async {
    final p = prefs;
    if (p == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotesScreen(prefs: p)),
    );
  }

  // নিচের বারের এক কলাম: লেবেল, টাকা, আর কয়টি জিনিস
  Widget _sum(String label, double v, int count, Color? color) {
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
        const SizedBox(height: 2),
        Text(
          '${bnStr(count.toString())}টি জিনিস',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = items.fold<double>(0, (s, e) => s + e.total);
    final boughtItems = items.where((e) => e.done).toList();
    final bought = boughtItems.fold<double>(0, (s, e) => s + e.total);
    final left = total - bought;
    final leftCount = items.length - boughtItems.length;
    final view = [
      ...items.where((e) => !e.done),
      ...items.where((e) => e.done),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('বাজারের তালিকা'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sticky_note_2_outlined),
            tooltip: 'সব নোট',
            onPressed: _openNotes,
          ),
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub),
                              if (item.created > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 13),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          fmtDateTime(item.created),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
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
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'note',
            onPressed: _newNote,
            icon: const Icon(Icons.edit_note),
            label: const Text('নোট করুন'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _editItem(),
            icon: const Icon(Icons.add),
            label: const Text('যোগ করুন'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: cs.primaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sum('মোট', total, items.length, null),
              _sum('কেনা হয়েছে', bought, boughtItems.length,
                  Colors.green.shade800),
              _sum('বাকি', left, leftCount, Colors.red.shade700),
            ],
          ),
        ),
      ),
    );
  }
}


class NotesScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const NotesScreen({super.key, required this.prefs});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final list = loadNotes(widget.prefs);
    list.sort((a, b) => b.updated.compareTo(a.updated));
    setState(() {
      notes = list;
    });
  }

  Future<void> _open([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditor(prefs: widget.prefs, note: note),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('সব নোট (${bnStr(notes.length.toString())}টি)'),
        centerTitle: true,
      ),
      body: notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'কোনো নোট নেই।\nনিচের "নতুন নোট" বোতামে ট্যাপ করে বাজারের পরিকল্পনা লিখুন।',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 90),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final n = notes[i];
                final title = n.title.trim().isEmpty ? '(শিরোনাম নেই)' : n.title;
                return Dismissible(
                  key: ObjectKey(n),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade400,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    final list = loadNotes(widget.prefs);
                    list.removeWhere((e) => e.id == n.id);
                    saveNotes(widget.prefs, list);
                    setState(() {
                      notes.remove(n);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('নোট মুছে ফেলা হয়েছে'),
                        action: SnackBarAction(
                          label: 'ফিরিয়ে আনুন',
                          onPressed: () {
                            final l = loadNotes(widget.prefs);
                            l.add(n);
                            saveNotes(widget.prefs, l);
                            _reload();
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
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.body.trim().isNotEmpty)
                            Text(
                              n.body.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  fmtDateTime(n.updated),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _open(n),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.edit_note),
        label: const Text('নতুন নোট'),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final SharedPreferences prefs;
  final Note? note;
  const NoteEditor({super.key, required this.prefs, this.note});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController titleC;
  late final TextEditingController bodyC;
  late final int id;
  late final int created;
  late int updated;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    titleC = TextEditingController(text: n?.title ?? '');
    bodyC = TextEditingController(text: n?.body ?? '');
    id = n?.id ?? nowMs;
    created = n?.created ?? nowMs;
    updated = n?.updated ?? nowMs;
  }

  @override
  void dispose() {
    titleC.dispose();
    bodyC.dispose();
    super.dispose();
  }

  // প্রতিবার লেখা বদলালে নিজে নিজে সংরক্ষণ হয়
  void _persist() {
    final title = titleC.text;
    final body = bodyC.text;
    final list = loadNotes(widget.prefs);
    final idx = list.indexWhere((e) => e.id == id);
    final empty = title.trim().isEmpty && body.trim().isEmpty;
    if (empty) {
      if (idx >= 0) list.removeAt(idx);
      saveNotes(widget.prefs, list);
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (idx >= 0) {
      list[idx].title = title;
      list[idx].body = body;
      list[idx].updated = nowMs;
    } else {
      list.add(Note(id, title, body, created, nowMs));
    }
    saveNotes(widget.prefs, list);
    setState(() {
      updated = nowMs;
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নোটটি মুছবেন?'),
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
      final list = loadNotes(widget.prefs);
      list.removeWhere((e) => e.id == id);
      saveNotes(widget.prefs, list);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'নতুন নোট' : 'নোট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'মুছুন',
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'লেখা হয়েছে: ${fmtDateTime(created)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (updated != created)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'সর্বশেষ বদল: ${fmtDateTime(updated)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            TextField(
              controller: titleC,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'শিরোনাম (যেমন: শুক্রবারের বাজার)',
                border: InputBorder.none,
              ),
              onChanged: (_) => _persist(),
            ),
            const Divider(height: 1),
            Expanded(
              child: TextField(
                controller: bodyC,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText:
                      'বাজারের পরিকল্পনা, কী কী কিনবেন, কোথায় যাবেন, বাজেট...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _persist(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
