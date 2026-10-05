import 'package:flutter/material.dart';
import 'stock_store.dart';
import 'stock_page.dart';
import 'documents_page.dart';
import 'features/pos/pos_page.dart';

class PosWorkspace extends StatefulWidget {
  final StockStore store;
  const PosWorkspace({super.key, required this.store});
  @override
  State<PosWorkspace> createState() => _PosWorkspaceState();
}

class _PosWorkspaceState extends State<PosWorkspace> {
  int selected = 0;
  static const destinations = [
    (Icons.point_of_sale_outlined, 'Point of sale'),
    (Icons.inventory_2_outlined, 'Products'),
    (Icons.receipt_long_outlined, 'Sales history'),
    (Icons.local_shipping_outlined, 'Purchases'),
    (Icons.warning_amber_rounded, 'Low stock'),
    (Icons.swap_vert, 'Stock history'),
  ];
  Widget navigation(bool drawer) => Material(
      color: const Color(0xFF111C32),
      child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(24, 30, 20, 32),
            child: Row(children: [
              Icon(Icons.bolt, color: Color(0xFFA5B4FC), size: 30),
              SizedBox(width: 10),
              Expanded(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('NEXUS POS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: 0.5))))
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('WORKSPACE',
                style: TextStyle(
                    color: Color(0xFF8190AC), letterSpacing: 2, fontSize: 10))),
        const SizedBox(height: 16),
        for (final entry in destinations.indexed)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  selected: selected == entry.$1,
                  selectedTileColor: const Color(0xFF4F46E5),
                  selectedColor: Colors.white,
                  textColor: const Color(0xFFB9C5DB),
                  iconColor: const Color(0xFFB9C5DB),
                  leading: Icon(entry.$2.$1, size: 21),
                  title:
                      Text(entry.$2.$2, style: const TextStyle(fontSize: 13)),
                  onTap: () {
                    setState(() => selected = entry.$1);
                    if (drawer) Navigator.pop(context);
                  })),
        const Spacer(),
        const Divider(color: Color(0xFF2C3850)),
        const Padding(
            padding: EdgeInsets.all(24),
            child: Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF5DD6AC), size: 16),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Offline workspace\nSaved on this device',
                      style: TextStyle(
                          color: Color(0xFFB9C5DB), fontSize: 11, height: 1.8)))
            ])),
      ])));
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Scaffold(
        drawer: wide ? null : Drawer(child: navigation(true)),
        appBar: AppBar(
          title: Text(destinations[selected].$2,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          actions: const [
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Chip(
                    avatar: Icon(Icons.computer, size: 16),
                    label: Text('Local store')))
          ],
        ),
        body: Row(children: [
          if (wide) SizedBox(width: 220, child: navigation(false)),
          Expanded(
              child: Stack(children: [
            Offstage(
                offstage: selected != 0,
                child: TickerMode(
                    enabled: selected == 0,
                    child:
                        PosPage(store: widget.store, active: selected == 0))),
            if (selected == 1 || selected >= 4)
              Positioned.fill(
                  child: StockPage(
                      key: ValueKey(selected),
                      store: widget.store,
                      embedded: true,
                      initialSection: selected == 4
                          ? 1
                          : selected == 5
                              ? 2
                              : 0)),
            if (selected == 2 || selected == 3)
              Positioned.fill(
                  child: DocumentsPage(
                      key: ValueKey(selected),
                      store: widget.store,
                      kind: selected == 2 ? 'sale' : 'purchase',
                      allowCreate: selected != 2,
                      onChanged: () async {})),
          ]))
        ]));
  }
}
