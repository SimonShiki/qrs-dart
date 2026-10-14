import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Lets the user choose what to send: a file, or a short piece of text.
class SourceCard extends StatelessWidget {
  /// Creates the source card for [controller].
  const SourceCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  Future<void> _sendText(BuildContext context) async {
    final textController = TextEditingController(text: 'Hello from qrs_dart!');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send text'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Text to send',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      controller.loadText(text);
      controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final hasData = controller.data.value != null;

        return SectionCard(
          title: 'Payload',
          subtitle: hasData
              ? '${controller.filename.value ?? 'unnamed'} · '
                    '${controller.data.value!.length} bytes'
              : 'Choose a file or send a short text',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await controller.pickFile();
                      controller.start();
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose file'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _sendText(context),
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Send text'),
                  ),
                ],
              ),
              if (controller.error.value != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.error.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
