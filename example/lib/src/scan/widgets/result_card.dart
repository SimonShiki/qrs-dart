import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

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

    return SignalBuilder(
      builder: (context) {
        final result = controller.result.value;
        if (result == null) return const SizedBox.shrink();

        final text = result.meta.contentType.startsWith('text/')
            ? utf8.decode(result.data, allowMalformed: true)
            : null;

        return SectionCard(
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(child: SelectableText(text)),
                ),
              if (text == null)
                Text(
                  'Binary payload: ${result.data.length} bytes ready to save.',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save file'),
              ),
            ],
          ),
        );
      },
    );
  }
}
