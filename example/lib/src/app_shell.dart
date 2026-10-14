import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'scan/scan_page.dart';
import 'send/send_page.dart';

/// Top-level navigation between the sending and receiving halves.
class AppShell extends StatefulWidget {
  /// Creates the shell.
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _index = signal(0);

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _index.value,
            children: const [SendPage(), ScanPage()],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index.value,
          onDestinationSelected: (value) => _index.value = value,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_2_outlined),
              selectedIcon: Icon(Icons.qr_code_2),
              label: 'Send',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
          ],
        ),
      ),
    );
  }
}
