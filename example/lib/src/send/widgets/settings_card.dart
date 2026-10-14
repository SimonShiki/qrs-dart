import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Transmission settings: block size and the scanner URL prefix.
class SettingsCard extends StatefulWidget {
  /// Creates the settings card for [controller].
  const SettingsCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  late final TextEditingController _sliceSize = TextEditingController(
    text: '${widget.controller.sliceSize.value}',
  );
  late final TextEditingController _prefix = TextEditingController(
    text: widget.controller.prefix.value,
  );

  @override
  void dispose() {
    _sliceSize.dispose();
    _prefix.dispose();
    super.dispose();
  }

  void _submitSliceSize(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;
    widget.controller.updateSliceSize(parsed);
    _sliceSize.text = '${widget.controller.sliceSize.value}';
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => SectionCard(
        title: 'Transmission',
        subtitle: 'Smaller blocks mean more frames but scan more reliably',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _sliceSize,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Block size (bytes)',
                helperText: '1 - 10000, default 1000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _submitSliceSize,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widget.controller.usePrefix.value,
              onChanged: (value) => widget.controller.usePrefix.value = value,
              title: const Text('Scanner URL prefix'),
              subtitle: const Text(
                'Lets the official web scanner open the payload directly',
              ),
            ),
            if (widget.controller.usePrefix.value)
              TextField(
                controller: _prefix,
                decoration: const InputDecoration(
                  labelText: 'Prefix',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => widget.controller.prefix.value = value,
              ),
          ],
        ),
      ),
    );
  }
}
