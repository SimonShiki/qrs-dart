import 'package:material_ui/material_ui.dart';

import '../widgets/page_body.dart';
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
    return M3PageBody(
      scrollKey: const PageStorageKey<String>('send-page'),
      headline: 'Stream a payload',
      supportingText:
          'Every frame carries one Luby Transform block. Point the scanner at '
          'the stream; frames may be missed without losing the transfer.',
      children: [
        SourceCard(
          key: const ValueKey<String>('SourceCard'),
          controller: _controller,
        ),
        StreamCard(
          key: const ValueKey<String>('StreamCard'),
          controller: _controller,
        ),
        SettingsCard(
          key: const ValueKey<String>('SettingsCard'),
          controller: _controller,
        ),
        StatsCard(
          key: const ValueKey<String>('StatsCard'),
          controller: _controller,
        ),
        GifExportCard(
          key: const ValueKey<String>('GifExportCard'),
          controller: _controller,
        ),
      ],
    );
  }
}
