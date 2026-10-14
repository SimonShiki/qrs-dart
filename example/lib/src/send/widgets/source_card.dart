import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
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
        title: const Text('Compose text'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(labelText: 'Text to send'),
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
    textController.dispose();

    if (text != null && text.isNotEmpty) {
      controller.loadText(text);
      controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SignalBuilder(
      builder: (context) {
        final data = controller.data.value;

        return SectionCard(
          title: 'Payload',
          subtitle: data != null
              ? '${controller.filename.value ?? 'unnamed'} · ${data.length} bytes'
              : 'Choose a file or send a short text',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrap instead of Row: the actions reflow onto a second line in
              // narrow windows or at large text scales.
              Wrap(
                spacing: M3Spacing.small,
                runSpacing: M3Spacing.small,
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
              if (controller.error.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: M3Spacing.medium),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: M3Spacing.small),
                      Expanded(
                        child: Text(
                          controller.error.value!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
