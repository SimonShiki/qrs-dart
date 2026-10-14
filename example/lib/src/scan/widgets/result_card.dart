import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
import '../../widgets/enter_transition.dart';
import '../../widgets/section_card.dart';
import '../scan_controller.dart';

/// Shows the decoded transfer and lets the user save it.
class ResultCard extends StatelessWidget {
  /// Creates the result card for [controller].
  const ResultCard({super.key, required this.controller});

  /// The scan controller driving the page.
  final ScanController controller;

  Future<void> _save() async {
    final result = controller.result.value;
    if (result == null) return;

    await FilePicker.saveFile(
      fileName: result.meta.filename ?? 'qrs-transfer.bin',
      bytes: Uint8List.fromList(result.data),
      mimeType: result.meta.contentType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SignalBuilder(
      builder: (context) {
        final result = controller.result.value;
        if (result == null) return const SizedBox.shrink();

        final text = result.meta.contentType.startsWith('text/')
            ? utf8.decode(result.data, allowMalformed: true)
            : null;

        // MD3 enter-the-screen motion, so the result announces itself instead
        // of snapping into place.
        return M3EnterTransition(
          child: SectionCard(
            title: 'Received',
            subtitle:
                '${result.meta.filename ?? 'unnamed'} · '
                '${result.data.length} bytes · ${result.meta.contentType}',
            trailing: IconButton(
              onPressed: controller.reset,
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reset',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (text != null)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(M3Spacing.medium),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: M3Shape.cardRadius,
                    ),
                    child: SingleChildScrollView(child: SelectableText(text)),
                  )
                else
                  Text(
                    'Binary payload: ${result.data.length} bytes ready to save.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: M3Spacing.large),
                Wrap(
                  spacing: M3Spacing.small,
                  runSpacing: M3Spacing.small,
                  children: [
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save file'),
                    ),
                    if (text != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                        },
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copy text'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
