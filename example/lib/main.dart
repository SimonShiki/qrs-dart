import 'package:material_ui/material_ui.dart';

import 'src/app_shell.dart';
import 'src/design/theme.dart';

void main() {
  runApp(const QrsExampleApp());
}

/// Example application for `package:qrs_dart`.
///
/// It pairs the two halves of the protocol: the *Send* page streams a file as
/// animated QR codes, and the *Scan* page collects frames from a camera and
/// rebuilds the file. Scanning is available on Android, iOS, macOS and the web;
/// on other platforms the scan page accepts pasted frame payloads so the
/// receiver can still be verified.
class QrsExampleApp extends StatelessWidget {
  /// Creates the example application.
  const QrsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRS Dart',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
