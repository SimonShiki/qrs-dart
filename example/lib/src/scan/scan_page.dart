import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../widgets/page_body.dart';
import 'scan_controller.dart';
import 'widgets/camera_card.dart';
import 'widgets/image_scan_card.dart';
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
    return SignalBuilder(
      builder: (context) => M3PageBody(
        scrollKey: const PageStorageKey<String>('scan-page'),
        headline: 'Receive a stream',
        supportingText:
            'Frames may be skipped or repeated: the fountain decoder only needs '
            'slightly more blocks than the payload has.',
        children: [
          // Only present once there is something to show, so the page does not
          // reserve an empty gap for the result card. The key keeps the state of
          // the cards below when this one appears.
          if (_controller.result.value != null)
            ResultCard(
              key: const ValueKey<String>('ResultCard'),
              controller: _controller,
            ),
          CameraCard(
            key: const ValueKey<String>('CameraCard'),
            controller: _controller,
          ),
          ImageScanCard(
            key: const ValueKey<String>('ImageScanCard'),
            controller: _controller,
          ),
          ProgressCard(
            key: const ValueKey<String>('ProgressCard'),
            controller: _controller,
          ),
          ManualInputCard(
            key: const ValueKey<String>('ManualInputCard'),
            controller: _controller,
          ),
        ],
      ),
    );
  }
}
