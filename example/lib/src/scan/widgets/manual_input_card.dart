import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
import '../../widgets/section_card.dart';
import '../scan_controller.dart';

/// Adds frame payloads by hand.
///
/// This keeps the receiver verifiable on platforms without a camera, and makes
/// it easy to replay a payload copied from the send page or the CLI.
class ManualInputCard extends StatefulWidget {
  /// Creates the manual input card for [controller].
  const ManualInputCard({super.key, required this.controller});

  /// The scan controller driving the page.
  final ScanController controller;

  @override
  State<ManualInputCard> createState() => _ManualInputCardState();
}

class _ManualInputCardState extends State<ManualInputCard> {
  final _input = TextEditingController();
  String? _feedback;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final payload = _input.text.trim();
    if (payload.isEmpty) return;
    final outcome = widget.controller.addPayload(payload);
    setState(
      () => _feedback = switch (outcome) {
        ScanOutcome.complete => 'Transfer complete',
        ScanOutcome.accepted => 'Block accepted',
        ScanOutcome.started => 'New transfer started',
        ScanOutcome.duplicate => 'Already seen this frame',
        ScanOutcome.refused => 'Kept the current transfer',
        ScanOutcome.invalid => 'Not a QRS frame payload',
        ScanOutcome.empty => 'Empty payload',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SignalBuilder(
      builder: (context) => SectionCard(
        variant: SectionCardVariant.outlined,
        title: 'Manual frame input',
        subtitle: 'Paste one frame payload per line',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              maxLines: 3,
              minLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                labelText: 'Frame payload',
                alignLabelWithHint: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: M3Spacing.medium),
            Wrap(
              spacing: M3Spacing.small,
              runSpacing: M3Spacing.small,
              children: [
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add frame'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _input.clear();
                    widget.controller.reset();
                    setState(() => _feedback = null);
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: M3Spacing.small),
              Semantics(
                liveRegion: true,
                child: Text(_feedback!, style: theme.textTheme.bodySmall),
              ),
            ],
            if (widget.controller.error.value != null) ...[
              const SizedBox(height: M3Spacing.small),
              Text(
                widget.controller.error.value!,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
