import 'package:flutter/material.dart';

import 'cash_closing_tab.dart';
import 'charge_form_tab.dart';

/// Cobro de mensualidades (socios). El cobro por día vive en su propia pantalla.
class ChargeScreen extends StatelessWidget {
  final String? preselectedMemberId;
  const ChargeScreen({super.key, this.preselectedMemberId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensualidades'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nuevo cobro'),
              Tab(text: 'Caja del día'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChargeFormTab(preselectedMemberId: preselectedMemberId),
            const CashClosingTab(),
          ],
        ),
      ),
    );
  }
}
