import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/skins/domain/skin.dart';
import 'package:studio/features/skins/presentation/skins_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';

/// Pick, import, export and remove skins in Settings → Skins.
class SkinsPanel extends ConsumerStatefulWidget {
  const SkinsPanel({super.key, this.pickSkinText, this.saveSkinFile});

  /// Test seams for the native file dialogs.
  final Future<String?> Function()? pickSkinText;
  final Future<bool> Function(String fileName, String contents)? saveSkinFile;

  @override
  ConsumerState<SkinsPanel> createState() => _SkinsPanelState();
}

class _SkinsPanelState extends ConsumerState<SkinsPanel> {
  String? _message;

  Future<String?> _pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import skin',
      type: FileType.custom,
      allowedExtensions: const [Skin.fileExtension, 'json'],
    );
    final path = file?.path;
    if (path == null) return null;
    final target = File(path);
    if (await target.length() > Skin.maxBytes) {
      throw const SkinFormatException('Skin files must be smaller than 64 KB.');
    }
    return target.readAsString();
  }

  Future<bool> _save(String fileName, String contents) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export skin',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(contents)),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const [Skin.fileExtension],
    );
    return saved != null;
  }

  Future<void> _import() async {
    try {
      final text = await (widget.pickSkinText ?? _pick)();
      if (text == null) return;
      final skin = ref.read(skinsProvider.notifier).import(text);
      setState(() => _message = 'Installed and applied “${skin.name}”.');
    } on SkinFormatException catch (error) {
      setState(() => _message = error.message);
    } on Object {
      setState(() => _message = 'Could not read that file.');
    }
  }

  Future<void> _export() async {
    final skin = ref.read(skinsProvider.notifier).exportable();
    final slug = skin.id.substring(0, skin.id.lastIndexOf('-'));
    try {
      final saved = await (widget.saveSkinFile ?? _save)(
        '$slug.${Skin.fileExtension}',
        skin.encode(),
      );
      if (saved && mounted) {
        setState(() => _message = 'Exported “${skin.name}”.');
      }
    } on Object {
      if (mounted) setState(() => _message = 'Could not save the skin file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    final state = ref.watch(skinsProvider);
    final notifier = ref.read(skinsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LibraryTextAction(
              label: 'Editorial (built-in)',
              muted: state.activeId != null,
              onTap: () => notifier.apply(null),
            ),
            for (final skin in state.skins)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LibraryTextAction(
                    label: skin.author == null
                        ? skin.name
                        : '${skin.name} · ${skin.author}',
                    muted: state.activeId != skin.id,
                    onTap: () => notifier.apply(skin.id),
                  ),
                  IconButton(
                    tooltip: 'Remove ${skin.name}',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: () => notifier.remove(skin.id),
                    icon: Icon(Icons.close, color: palette.inkMuted),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            TextButton(
              key: const ValueKey('skin-import'),
              onPressed: _import,
              child: const Text('Import skin…'),
            ),
            TextButton(
              key: const ValueKey('skin-export'),
              onPressed: _export,
              child: const Text('Export skin…'),
            ),
          ],
        ),
        Text(
          _message ??
              'Skins recolour surfaces and text in light and dark mode. The accent still follows your album art or custom colour.',
          key: const ValueKey('skin-message'),
          style: muted,
        ),
      ],
    );
  }
}
