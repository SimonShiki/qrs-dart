import 'package:material_ui/material_ui.dart';

import 'send_controller.dart';
import 'widgets/gif_export_card.dart';
import 'widgets/settings_card.dart';
import 'widgets/source_card.dart';
import 'widgets/stats_card.dart';
import 'widgets/stream_card.dart';

/// Sending half of the example app: streams a payload as animated QR codes.
class SendPage extends StatefulWidget {
  /// Creates the send page.
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _controller = SendController();

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
          child: Text('Send', style: Theme.of(context).textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Every frame carries one Luby Transform block. Point the scanner at '
            'the stream; frames may be missed without losing the transfer.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SourceCard(controller: _controller),
        StreamCard(controller: _controller),
        SettingsCard(controller: _controller),
        StatsCard(controller: _controller),
        GifExportCard(controller: _controller),
      ],
    );
  }
}
