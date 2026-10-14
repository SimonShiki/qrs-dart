import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'design/tokens.dart';
import 'scan/scan_page.dart';
import 'send/send_page.dart';

/// One top-level destination of the shell.
class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

const List<_Destination> _destinations = <_Destination>[
  _Destination(
    label: 'Send',
    icon: Icons.qr_code_2_outlined,
    selectedIcon: Icons.qr_code_2,
    page: SendPage(),
  ),
  _Destination(
    label: 'Scan',
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
    page: ScanPage(),
  ),
];

/// Top-level navigation between the sending and receiving halves.
///
/// The navigation component follows the MD3 window size classes: a
/// [NavigationBar] on compact windows, a [NavigationRail] on medium windows and
/// an extended rail once the window is expanded. The two destinations keep their
/// state, so a transfer started on *Send* survives a trip to *Scan*, and each
/// destination gets a top app bar that tints as its content scrolls beneath it.
class AppShell extends StatefulWidget {
  /// Creates the shell.
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _selected = signal(0);

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'QRS Dart',
      applicationVersion: '0.1.0',
      applicationIcon: const Icon(Icons.qr_code_2, size: 40),
      children: const [
        Text(
          'Transfer any file as a fountain-coded stream of animated QR codes. '
          'Frames may be dropped or repeated; the receiver only needs slightly '
          'more blocks than the payload has.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final index = _selected.value;

        return LayoutBuilder(
          builder: (context, constraints) {
            final windowSize = M3WindowSize.fromWidth(constraints.maxWidth);
            final usesRail = windowSize.usesNavigationRail;
            final extendedRail = windowSize.usesExtendedNavigationRail;

            final pages = IndexedStack(
              index: index,
              children: [
                for (final destination in _destinations) destination.page,
              ],
            );

            return Scaffold(
              body: SafeArea(
                // Either the navigation bar (compact) or the page body owns the
                // bottom inset, never both.
                bottom: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (usesRail) ...[
                      _Rail(
                        selectedIndex: index,
                        extended: extendedRail,
                        onSelected: (value) => _selected.value = value,
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: Column(
                        children: [
                          AppBar(
                            // The SafeArea above already consumed the status bar.
                            primary: false,
                            title: Text(_destinations[index].label),
                            actions: [
                              IconButton(
                                onPressed: () => _showAbout(context),
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'About this example',
                              ),
                              const SizedBox(width: M3Spacing.extraSmall),
                            ],
                          ),
                          Expanded(
                            child: usesRail
                                ? pages
                                : MediaQuery.removePadding(
                                    context: context,
                                    removeBottom: true,
                                    child: pages,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: windowSize.usesNavigationBar
                  ? _Bar(
                      selectedIndex: index,
                      onSelected: (value) => _selected.value = value,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Compact-window navigation: an MD3 [NavigationBar].
class _Bar extends StatelessWidget {
  const _Bar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

/// Medium and larger windows: an MD3 [NavigationRail], extended when there is
/// room for labels beside the icons.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      // An extended rail shows labels beside the icons, so the inline label
      // mode must be off; the collapsed rail always shows them.
      labelType: extended ? null : NavigationRailLabelType.all,
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
