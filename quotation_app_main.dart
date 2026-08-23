import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const QuotationApp());

class QuotationApp extends StatelessWidget {
  const QuotationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saini Quotation Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xfff5f7fb),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Client {
  String id, name, mobile, address, gst, email, remark;

  Client({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.gst,
    required this.email,
    required this.remark,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'address': address,
        'gst': gst,
        'email': email,
        'remark': remark,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        mobile: '${j['mobile'] ?? ''}',
        address: '${j['address'] ?? ''}',
        gst: '${j['gst'] ?? ''}',
        email: '${j['email'] ?? ''}',
        remark: '${j['remark'] ?? ''}',
      );
}

class QuoteItem {
  String name, unit;
  double qty, rate;

  QuoteItem({
    required this.name,
    required this.unit,
    required this.qty,
    required this.rate,
  });

  double get amount => qty * rate;

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'qty': qty,
        'rate': rate,
      };

  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? 'Nos'}',
        qty: double.tryParse('${j['qty'] ?? 0}') ?? 0,
        rate: double.tryParse('${j['rate'] ?? 0}') ?? 0,
      );
}

class Quotation {
  String id, number, type, clientId, note, validity, terms;
  DateTime date;
  List<QuoteItem> items;

  Quotation({
    required this.id,
    required this.number,
    required this.type,
    required this.clientId,
    required this.date,
    required this.items,
    required this.note,
    required this.validity,
    required this.terms,
  });

  double get total => items.fold(0, (s, i) => s + i.amount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'type': type,
        'clientId': clientId,
        'date': date.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'note': note,
        'validity': validity,
        'terms': terms,
      };

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: '${j['id'] ?? ''}',
        number: '${j['number'] ?? ''}',
        type: '${j['type'] ?? 'CCTV'}',
        clientId: '${j['clientId'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}') ?? DateTime.now(),
        items: ((j['items'] as List?) ?? [])
            .map((e) => QuoteItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        note: '${j['note'] ?? ''}',
        validity: '${j['validity'] ?? '15 Days'}',
        terms: '${j['terms'] ?? ''}',
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const dataKey = 'saini_quote_data_v1';
  static const settingsKey = 'saini_quote_settings_v1';

  String firmName = 'Saini Info Solutions';
  String firmAddress = '';
  String firmPhone = '';
  String firmEmail = '';
  String gst = '';
  String cctvPrefix = 'CCTV-';
  String computerPrefix = 'COMP-';
  int cctvNext = 1;
  int computerNext = 1;

  final clients = <Client>[];
  final quotations = <Quotation>[];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  String money(double n) => '₹ ${n.toStringAsFixed(2)}';
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    final s = sp.getString(settingsKey);
    if (s != null) {
      try {
        final j = jsonDecode(s);
        firmName = '${j['firmName'] ?? firmName}';
        firmAddress = '${j['firmAddress'] ?? ''}';
        firmPhone = '${j['firmPhone'] ?? ''}';
        firmEmail = '${j['firmEmail'] ?? ''}';
        gst = '${j['gst'] ?? ''}';
        cctvPrefix = '${j['cctvPrefix'] ?? 'CCTV-'}';
        computerPrefix = '${j['computerPrefix'] ?? 'COMP-'}';
        cctvNext = int.tryParse('${j['cctvNext'] ?? 1}') ?? 1;
        computerNext = int.tryParse('${j['computerNext'] ?? 1}') ?? 1;
      } catch (_) {}
    }

    final d = sp.getString(dataKey);
    if (d != null) {
      try {
        final j = jsonDecode(d);
        clients
          ..clear()
          ..addAll(((j['clients'] as List?) ?? [])
              .map((e) => Client.fromJson(Map<String, dynamic>.from(e))));
        quotations
          ..clear()
          ..addAll(((j['quotations'] as List?) ?? [])
              .map((e) => Quotation.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      settingsKey,
      jsonEncode({
        'firmName': firmName,
        'firmAddress': firmAddress,
        'firmPhone': firmPhone,
        'firmEmail': firmEmail,
        'gst': gst,
        'cctvPrefix': cctvPrefix,
        'computerPrefix': computerPrefix,
        'cctvNext': cctvNext,
        'computerNext': computerNext,
      }),
    );
    await sp.setString(
      dataKey,
      jsonEncode({
        'clients': clients.map((e) => e.toJson()).toList(),
        'quotations': quotations.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Client? clientById(String id) {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  String newNumber(String type) {
    if (type == 'CCTV') return '$cctvPrefix$cctvNext';
    return '$computerPrefix$computerNext';
  }

  Future<void> settings() async {
    final n = TextEditingController(text: firmName);
    final a = TextEditingController(text: firmAddress);
    final p = TextEditingController(text: firmPhone);
    final e = TextEditingController(text: firmEmail);
    final g = TextEditingController(text: gst);
    final cp = TextEditingController(text: cctvPrefix);
    final xp = TextEditingController(text: computerPrefix);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firm & Quotation Settings'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                field(n, 'Firm Name'),
                field(a, 'Firm Address'),
                field(p, 'Phone'),
                field(e, 'Email'),
                field(g, 'GST No.'),
                field(cp, 'CCTV Quotation Prefix'),
                field(xp, 'Computer Quotation Prefix'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      firmName = n.text.trim().isEmpty ? 'Saini Info Solutions' : n.text.trim();
      firmAddress = a.text.trim();
      firmPhone = p.text.trim();
      firmEmail = e.text.trim();
      gst = g.text.trim();
      cctvPrefix = cp.text.trim();
      computerPrefix = xp.text.trim();
      await save();
      if (mounted) setState(() {});
    }

    for (final c in [n, a, p, e, g, cp, xp]) {
      c.dispose();
    }
  }

  Future<Client?> clientForm({Client? old}) async {
    final n = TextEditingController(text: old?.name ?? '');
    final m = TextEditingController(text: old?.mobile ?? '');
    final a = TextEditingController(text: old?.address ?? '');
    final g = TextEditingController(text: old?.gst ?? '');
    final e = TextEditingController(text: old?.email ?? '');
    final r = TextEditingController(text: old?.remark ?? '');

    final result = await showDialog<Client>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'Add Client' : 'Update Client'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                field(n, 'Client Name *'),
                field(m, 'Mobile No. *', TextInputType.phone),
                field(a, 'Address'),
                field(g, 'GST No.'),
                field(e, 'Email', TextInputType.emailAddress),
                field(r, 'Remark'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (n.text.trim().isEmpty || m.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                Client(
                  id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  name: n.text.trim(),
                  mobile: m.text.trim(),
                  address: a.text.trim(),
                  gst: g.text.trim(),
                  email: e.text.trim(),
                  remark: r.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    for (final c in [n, m, a, g, e, r]) {
      c.dispose();
    }
    return result;
  }

  Future<void> clientsPage() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Client Management')),
              IconButton(onPressed: () async {
                final c = await clientForm();
                if (c != null) {
                  clients.add(c);
                  await save();
                  setD(() {});
                  setState(() {});
                }
              }, icon: const Icon(Icons.person_add)),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 500,
            child: clients.isEmpty
                ? const Center(child: Text('No clients added'))
                : ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                        title: Text(c.name),
                        subtitle: Text('${c.mobile}\n${c.address}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Update',
                              onPressed: () async {
                                final v = await clientForm(old: c);
                                if (v != null) {
                                  final ix = clients.indexOf(c);
                                  clients[ix] = v;
                                  await save();
                                  setD(() {});
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                final yes = await confirm('Delete this client?');
                                if (yes) {
                                  clients.remove(c);
                                  await save();
                                  setD(() {});
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<List<QuoteItem>?> itemsForm(List<QuoteItem> initial) async {
    final rows = initial
        .map((e) => {
              'n': TextEditingController(text: e.name),
              'u': TextEditingController(text: e.unit),
              'q': TextEditingController(text: e.qty.toString()),
              'r': TextEditingController(text: e.rate.toString()),
            })
        .toList();

    if (rows.isEmpty) {
      rows.add({
        'n': TextEditingController(),
        'u': TextEditingController(text: 'Nos'),
        'q': TextEditingController(text: '1'),
        'r': TextEditingController(text: '0'),
      });
    }

    final result = await showDialog<List<QuoteItem>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Quotation Items'),
          content: SizedBox(
            width: 900,
            height: 560,
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(flex: 5, child: Text('ITEM NAME')),
                    SizedBox(width: 10),
                    SizedBox(width: 100, child: Text('UNIT')),
                    SizedBox(width: 10),
                    SizedBox(width: 90, child: Text('QTY')),
                    SizedBox(width: 10),
                    SizedBox(width: 120, child: Text('RATE')),
                    SizedBox(width: 48),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: field(r['n']!, 'Item Name')),
                            const SizedBox(width: 10),
                            SizedBox(width: 100, child: field(r['u']!, 'Unit')),
                            const SizedBox(width: 10),
                            SizedBox(width: 90, child: field(r['q']!, 'Qty', TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 10),
                            SizedBox(width: 120, child: field(r['r']!, 'Rate', TextInputType.numberWithOptions(decimal: true))),
                            IconButton(
                              onPressed: rows.length == 1 ? null : () {
                                for (final key in ['n', 'u', 'q', 'r']) {
                                  r[key]!.dispose();
                                }
                                rows.removeAt(i);
                                setD(() {});
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      rows.add({
                        'n': TextEditingController(),
                        'u': TextEditingController(text: 'Nos'),
                        'q': TextEditingController(text: '1'),
                        'r': TextEditingController(text: '0'),
                      });
                      setD(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final result = <QuoteItem>[];
                for (final r in rows) {
                  final name = r['n']!.text.trim();
                  if (name.isEmpty) continue;
                  result.add(
                    QuoteItem(
                      name: name,
                      unit: r['u']!.text.trim().isEmpty ? 'Nos' : r['u']!.text.trim(),
                      qty: double.tryParse(r['q']!.text.trim()) ?? 0,
                      rate: double.tryParse(r['r']!.text.trim()) ?? 0,
                    ),
                  );
                }
                Navigator.pop(ctx, result);
              },
              child: const Text('Save Items'),
            ),
          ],
        ),
      ),
    );

    for (final r in rows) {
      for (final key in ['n', 'u', 'q', 'r']) {
        r[key]!.dispose();
      }
    }
    return result;
  }

  Future<Quotation?> quotationForm({Quotation? old}) async {
    String type = old?.type ?? 'CCTV';
    String clientId = old?.clientId ?? (clients.isNotEmpty ? clients.first.id : '');
    DateTime qDate = old?.date ?? DateTime.now();
    List<QuoteItem> items = old?.items.map((e) => QuoteItem(name: e.name, unit: e.unit, qty: e.qty, rate: e.rate)).toList() ?? [];
    final note = TextEditingController(text: old?.note ?? '');
    final validity = TextEditingController(text: old?.validity ?? '15 Days');
    final terms = TextEditingController(text: old?.terms ?? 'Prices are subject to confirmation. Installation and taxes as applicable.');

    if (clients.isEmpty && old == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle client add karein.')));
      return null;
    }

    final result = await showDialog<Quotation>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(old == null ? 'Create Quotation' : 'Update Quotation'),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Quotation Format'),
                          items: const [
                            DropdownMenuItem(value: 'CCTV', child: Text('CCTV Quotation')),
                            DropdownMenuItem(value: 'Computer', child: Text('Computer Quotation')),
                          ],
                          onChanged: (v) => setD(() => type = v ?? type),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: clientId.isEmpty ? null : clientId,
                          decoration: const InputDecoration(labelText: 'Client'),
                          items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setD(() => clientId = v ?? clientId),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Quotation No.: ${old?.number ?? newNumber(type)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: qDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setD(() => qDate = d);
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(date(qDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final v = await itemsForm(items);
                      if (v != null) setD(() => items = v);
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text('${items.length} Items — Add / Update / Delete'),
                  ),
                  if (items.isNotEmpty)
                    Card(
                      child: Column(
                        children: [
                          const ListTile(title: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold))),
                          for (int i = 0; i < items.length; i++)
                            ListTile(
                              title: Text(items[i].name),
                              subtitle: Text('${items[i].qty} ${items[i].unit} × ${money(items[i].rate)}'),
                              trailing: Text(money(items[i].amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  field(note, 'Note / Description'),
                  field(validity, 'Quotation Validity'),
                  field(terms, 'Terms & Conditions', TextInputType.multiline),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (clientId.isEmpty || items.isEmpty) return;
                Navigator.pop(
                  ctx,
                  Quotation(
                    id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    number: old?.number ?? newNumber(type),
                    type: type,
                    clientId: clientId,
                    date: qDate,
                    items: items,
                    note: note.text.trim(),
                    validity: validity.text.trim(),
                    terms: terms.text.trim(),
                  ),
                );
              },
              child: const Text('Save Quotation'),
            ),
          ],
        ),
      ),
    );

    note.dispose();
    validity.dispose();
    terms.dispose();
    return result;
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        ),
      ) ??
      false;

  Future<File> makePdf(Quotation q) async {
    final client = clientById(q.clientId);
    final pdf = pw.Document();

    final normal = pw.TextStyle(fontSize: 9);
    final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final title = pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold);
    final section = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(firmName, style: title),
                    if (firmAddress.isNotEmpty) pw.Text(firmAddress, style: normal),
                    if (firmPhone.isNotEmpty) pw.Text('Phone: $firmPhone', style: normal),
                    if (firmEmail.isNotEmpty) pw.Text('Email: $firmEmail', style: normal),
                    if (gst.isNotEmpty) pw.Text('GST: $gst', style: normal),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  children: [
                    pw.Text('QUOTATION', style: bold),
                    pw.SizedBox(height: 5),
                    pw.Text(q.number, style: section),
                    pw.SizedBox(height: 4),
                    pw.Text(date(q.date), style: normal),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Text(q.type == 'CCTV' ? 'CCTV SYSTEM ESTIMATE / QUOTATION' : 'COMPUTER SYSTEM ESTIMATE / QUOTATION', style: section),
          ),
          pw.SizedBox(height: 14),
          pw.Text('CLIENT DETAILS', style: section),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(3)},
            children: [
              infoRow('Client Name', client?.name ?? '-'),
              infoRow('Mobile', client?.mobile ?? '-'),
              infoRow('Address', client?.address ?? '-'),
              if ((client?.gst ?? '').isNotEmpty) infoRow('GST No.', client!.gst),
              if ((client?.email ?? '').isNotEmpty) infoRow('Email', client!.email),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('ITEM DETAILS', style: section),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell('S.No', bold),
                  cell('Item Name', bold),
                  cell('Qty', bold),
                  cell('Unit', bold),
                  cell('Rate', bold),
                  cell('Amount', bold),
                ],
              ),
              ...q.items.asMap().entries.map(
                    (e) => pw.TableRow(
                      children: [
                        cell('${e.key + 1}', normal),
                        cell(e.value.name, normal),
                        cell(e.value.qty.toString(), normal),
                        cell(e.value.unit, normal),
                        cell(e.value.rate.toStringAsFixed(2), normal),
                        cell(e.value.amount.toStringAsFixed(2), normal),
                      ],
                    ),
                  ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL', style: bold),
                  pw.Text(money(q.total), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (q.note.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('DESCRIPTION / NOTE', style: section),
            pw.SizedBox(height: 5),
            pw.Text(q.note, style: normal),
          ],
          pw.SizedBox(height: 18),
          pw.Text('TERMS & CONDITIONS', style: section),
          pw.SizedBox(height: 5),
          pw.Text(q.terms.isEmpty ? '-' : q.terms, style: normal),
          pw.SizedBox(height: 8),
          pw.Text('Quotation Validity: ${q.validity}', style: bold),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Thank you for your enquiry.', style: normal),
              pw.Text('For $firmName', style: bold),
            ],
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safe = q.number.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/Quotation_$safe.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  pw.TableRow infoRow(String a, String b) => pw.TableRow(children: [
        cell(a, pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        cell(b, pw.TextStyle(fontSize: 9)),
      ]);

  pw.Padding cell(String s, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(s, style: style),
      );

  Future<void> downloadPdf(Quotation q) async {
    try {
      final f = await makePdf(q);
      final safe = q.number.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Quotation PDF',
        fileName: 'Quotation_$safe.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: await f.readAsBytes(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path == null ? 'Save cancelled' : 'PDF saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    }
  }

  Future<void> sharePdf(Quotation q) async {
    final f = await makePdf(q);
    await Share.shareXFiles([XFile(f.path)], text: 'Quotation ${q.number} - ${clientById(q.clientId)?.name ?? ''}');
  }

  Future<void> whatsapp(Quotation q) async {
    final c = clientById(q.clientId);
    if (c == null) return;

    final phone = c.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final n = phone.startsWith('91') ? phone : '91$phone';
    final lines = <String>[
      firmName,
      if (firmPhone.isNotEmpty) 'Phone: $firmPhone',
      '',
      'QUOTATION: ${q.number}',
      'Date: ${date(q.date)}',
      'Client: ${c.name}',
      '',
      ...q.items.asMap().entries.map((e) => '${e.key + 1}. ${e.value.name} - ${e.value.qty} ${e.value.unit} × ${e.value.rate.toStringAsFixed(2)} = ${e.value.amount.toStringAsFixed(2)}'),
      '',
      'GRAND TOTAL: ${money(q.total)}',
      'Validity: ${q.validity}',
    ];

    final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(lines.join('\n'))}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> backup() async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'firm': {
        'name': firmName,
        'address': firmAddress,
        'phone': firmPhone,
        'email': firmEmail,
        'gst': gst,
        'cctvPrefix': cctvPrefix,
        'computerPrefix': computerPrefix,
        'cctvNext': cctvNext,
        'computerNext': computerNext,
      },
      'clients': clients.map((e) => e.toJson()).toList(),
      'quotations': quotations.map((e) => e.toJson()).toList(),
    });

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: 'Saini_Quotation_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(json),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? 'Backup cancelled' : 'Backup saved successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup error: $e')));
    }
  }

  Future<void> restore() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (r == null) return;
      final file = r.files.single;
      final text = file.bytes != null ? utf8.decode(file.bytes!) : await File(file.path!).readAsString();
      final j = jsonDecode(text);

      if (j is! Map || j['clients'] is! List || j['quotations'] is! List) {
        throw const FormatException('Invalid backup');
      }

      final ok = await confirm('Current data replace ho jayega. Backup restore karein?');
      if (!ok) return;

      clients
        ..clear()
        ..addAll((j['clients'] as List).map((e) => Client.fromJson(Map<String, dynamic>.from(e))));
      quotations
        ..clear()
        ..addAll((j['quotations'] as List).map((e) => Quotation.fromJson(Map<String, dynamic>.from(e))));

      final f = Map<String, dynamic>.from(j['firm'] ?? {});
      firmName = '${f['name'] ?? firmName}';
      firmAddress = '${f['address'] ?? ''}';
      firmPhone = '${f['phone'] ?? ''}';
      firmEmail = '${f['email'] ?? ''}';
      gst = '${f['gst'] ?? ''}';
      cctvPrefix = '${f['cctvPrefix'] ?? 'CCTV-'}';
      computerPrefix = '${f['computerPrefix'] ?? 'COMP-'}';
      cctvNext = int.tryParse('${f['cctvNext'] ?? 1}') ?? 1;
      computerNext = int.tryParse('${f['computerNext'] ?? 1}') ?? 1;

      await save();
      if (mounted) setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  Future<void> newQuotation() async {
    final q = await quotationForm();
    if (q == null) return;
    quotations.insert(0, q);
    if (q.type == 'CCTV') {
      cctvNext++;
    } else {
      computerNext++;
    }
    await save();
    setState(() {});
  }

  Future<void> editQuotation(Quotation q) async {
    final v = await quotationForm(old: q);
    if (v == null) return;
    final i = quotations.indexOf(q);
    quotations[i] = v;
    await save();
    setState(() {});
  }

  Future<void> quotationList() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Quotations / Estimates'),
          content: SizedBox(
            width: 950,
            height: 560,
            child: quotations.isEmpty
                ? const Center(child: Text('No quotation created'))
                : ListView.separated(
                    itemCount: quotations.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final q = quotations[i];
                      final c = clientById(q.clientId);
                      return ListTile(
                        leading: CircleAvatar(child: Text(q.type == 'CCTV' ? 'C' : 'PC')),
                        title: Text('${q.number} • ${c?.name ?? 'Client'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${q.type} • ${date(q.date)} • ${q.items.length} items'),
                        trailing: Wrap(
                          children: [
                            IconButton(tooltip: 'Edit', onPressed: () async {
                              await editQuotation(q);
                              setD(() {});
                            }, icon: const Icon(Icons.edit)),
                            IconButton(tooltip: 'PDF Download', onPressed: () => downloadPdf(q), icon: const Icon(Icons.picture_as_pdf)),
                            IconButton(tooltip: 'WhatsApp', onPressed: () => whatsapp(q), icon: const Icon(Icons.message, color: Colors.green)),
                            IconButton(tooltip: 'Delete', onPressed: () async {
                              if (await confirm('Delete ${q.number}?')) {
                                quotations.remove(q);
                                await save();
                                setD(() {});
                                setState(() {});
                              }
                            }, icon: const Icon(Icons.delete_outline, color: Colors.red)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  Widget field(TextEditingController c, String label, [TextInputType type = TextInputType.text]) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: type,
          maxLines: type == TextInputType.multiline ? 4 : 1,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget dashboardCard(String title, String value, IconData icon, VoidCallback onTap) => Card(
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(radius: 25, child: Icon(icon)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(firmName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Clients', onPressed: clientsPage, icon: const Icon(Icons.people_alt_outlined)),
          IconButton(tooltip: 'Settings', onPressed: settings, icon: const Icon(Icons.settings_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'backup') backup();
              if (v == 'restore') restore();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'backup', child: ListTile(leading: Icon(Icons.backup), title: Text('Backup Data'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'restore', child: ListTile(leading: Icon(Icons.restore), title: Text('Restore Data'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 850;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quotation Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('CCTV aur Computer ke professional estimates / quotations banayein.'),
                          const SizedBox(height: 20),
                          GridView.count(
                            crossAxisCount: wide ? 3 : 1,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: wide ? 2.6 : 4.2,
                            children: [
                              dashboardCard('Clients', '${clients.length}', Icons.people_alt_outlined, clientsPage),
                              dashboardCard('Quotations', '${quotations.length}', Icons.receipt_long_outlined, quotationList),
                              dashboardCard('Total Estimate Value', money(quotations.fold(0, (s, q) => s + q.total)), Icons.currency_rupee, quotationList),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: newQuotation,
                                  icon: const Icon(Icons.add),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Text('New Quotation / Estimate'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: clientsPage,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Text('Manage Clients'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quotation Formats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          if (clients.isEmpty) {
                                            await clientsPage();
                                          } else {
                                            await newQuotation();
                                          }
                                        },
                                        icon: const Icon(Icons.videocam_outlined),
                                        label: const Text('CCTV Estimate'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          if (clients.isEmpty) {
                                            await clientsPage();
                                          } else {
                                            final q = await quotationForm();
                                            if (q != null) {
                                              q.type = 'Computer';
                                              q.number = newNumber('Computer');
                                              quotations.insert(0, q);
                                              computerNext++;
                                              await save();
                                              setState(() {});
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.computer_outlined),
                                        label: const Text('Computer Estimate'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: quotationList,
                                        icon: const Icon(Icons.history),
                                        label: const Text('Quotation History'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: newQuotation,
        icon: const Icon(Icons.receipt_long),
        label: const Text('New Quotation'),
      ),
    );
  }
}
