import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
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
    final theme = Theme.of(context);

    return SignalBuilder(
      builder: (context) => SectionCard(
        // Outlined variant: settings are a recessive surface next to the
        // filled payload and stream cards.
        variant: SectionCardVariant.outlined,
        title: 'Transmission',
        subtitle: 'Smaller blocks mean more frames but scan more reliably',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: M3Spacing.small,
              runSpacing: M3Spacing.small,
              children: [
                for (final preset in slicePresets)
                  ChoiceChip(
                    label: Text('${preset.label} · ${preset.sliceSize} B'),
                    selected:
                        widget.controller.sliceSize.value == preset.sliceSize,
                    onSelected: (_) {
                      widget.controller.applySlicePreset(preset);
                      _sliceSize.text = '${widget.controller.sliceSize.value}';
                    },
                  ),
              ],
            ),
            const SizedBox(height: M3Spacing.small),
            Text(
              slicePresets
                  .map((preset) => '${preset.label}: ${preset.detail}')
                  .join('\n'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: M3Spacing.medium),
            TextField(
              controller: _sliceSize,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Block size (bytes)',
                helperText: '1 - 10000, default 1000 · advanced',
              ),
              // Committing on focus loss as well as on Enter means the setting
              // never silently keeps an edited-but-unsubmitted value.
              onSubmitted: _submitSliceSize,
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                _submitSliceSize(_sliceSize.text);
              },
            ),
            const SizedBox(height: M3Spacing.medium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widget.controller.compress.value,
              onChanged: widget.controller.updateCompress,
              title: const Text('Compress payload'),
              subtitle: const Text(
                'Turn off for already compressed files (JPEG, ZIP, MP4, ...)',
              ),
            ),
            const SizedBox(height: M3Spacing.medium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widget.controller.usePrefix.value,
              onChanged: (value) => widget.controller.usePrefix.value = value,
              title: const Text('Scanner URL prefix'),
              subtitle: const Text(
                'Lets the official web scanner open the payload directly',
              ),
            ),
            if (widget.controller.usePrefix.value) ...[
              const SizedBox(height: M3Spacing.small),
              TextField(
                controller: _prefix,
                decoration: const InputDecoration(
                  labelText: 'Prefix',
                  helperText: 'Prepended to every frame',
                ),
                onChanged: (value) => widget.controller.prefix.value = value,
              ),
            ],
            const SizedBox(height: M3Spacing.medium),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: M3Spacing.small),
                Expanded(
                  child: Text(
                    'Changing the block size rebuilds the transfer from the '
                    'next frame on.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
