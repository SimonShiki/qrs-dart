import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
    return SignalBuilder(
      builder: (context) => SectionCard(
        title: 'Manual frame input',
        subtitle: 'Paste one frame payload per line',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Frame payload',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add frame'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _input.clear();
                    widget.controller.reset();
                    setState(() => _feedback = null);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 4),
              Text(_feedback!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (widget.controller.error.value != null)
              Text(
                widget.controller.error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
