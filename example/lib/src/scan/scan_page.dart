import 'package:material_ui/material_ui.dart';

import 'scan_controller.dart';
import 'widgets/camera_card.dart';
import 'widgets/manual_input_card.dart';
import 'widgets/progress_card.dart';
import 'widgets/result_card.dart';

/// Receiving half of the example app: rebuilds a payload from scanned frames.
class ScanPage extends StatefulWidget {
  /// Creates the scan page.
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = ScanController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Scan', style: Theme.of(context).textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Frames may be skipped or repeated: the fountain decoder only needs '
            'slightly more blocks than the payload has.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        ResultCard(controller: _controller),
        CameraCard(controller: _controller),
        ProgressCard(controller: _controller),
        ManualInputCard(controller: _controller),
      ],
    );
  }
}
