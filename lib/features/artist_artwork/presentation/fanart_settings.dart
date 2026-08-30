import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/theming/studio_palette.dart';

final fanartSettingsStoreProvider = Provider((ref) => FanartSettingsStore());
final fanartSettingsProvider =
    NotifierProvider<FanartSettingsNotifier, FanartSettings>(
      FanartSettingsNotifier.new,
    );

class FanartSettingsNotifier extends Notifier<FanartSettings> {
  bool _saving = false;
  @override
  FanartSettings build() => ref.watch(fanartSettingsStoreProvider).load();

  Future<void> save(String projectKey, String personalKey) async {
    if (_saving) throw StateError('Settings save already in progress');
    projectKey = projectKey.trim();
    personalKey = personalKey.trim();
    for (final key in [projectKey, personalKey]) {
      if (key.isNotEmpty && !RegExp(r'^[a-fA-F0-9]{16,128}$').hasMatch(key)) {
        throw const FormatException(
          'Keys must contain only letters a–f and numbers, without quotes.',
        );
      }
    }
    if (projectKey == state.projectKey && personalKey == state.personalKey) {
      return;
    }
    _saving = true;
    try {
      final next = FanartSettings(
        projectKey: projectKey,
        personalKey: personalKey,
        revision: state.revision + 1,
      );
      await ref.read(fanartSettingsStoreProvider).save(next);
      state = next;
    } finally {
      _saving = false;
    }
  }
}

class FanartSettingsPanel extends ConsumerStatefulWidget {
  const FanartSettingsPanel({super.key});
  @override
  ConsumerState<FanartSettingsPanel> createState() =>
      _FanartSettingsPanelState();
}

class _FanartSettingsPanelState extends ConsumerState<FanartSettingsPanel> {
  late final TextEditingController _project;
  late final TextEditingController _personal;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(fanartSettingsProvider);
    _project = TextEditingController(text: settings.projectKey);
    _personal = TextEditingController(text: settings.personalKey);
  }

  @override
  void dispose() {
    _project.dispose();
    _personal.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(fanartSettingsProvider.notifier)
          .save(remove ? '' : _project.text, remove ? '' : _personal.text);
      if (!mounted) return;
      if (remove) {
        _project.clear();
        _personal.clear();
      }
      setState(
        () => _message = remove
            ? 'Keys removed. Cached images are kept.'
            : 'Saved locally. Background fetching uses these keys; check the console for service responses.',
      );
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message
              : 'Could not save keys. Previous settings are unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(fanartSettingsProvider);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: StudioPalette.of(context).inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'fanart.tv artist portraits',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional: project key, personal key, or both. Keys are stored unencrypted in this device’s app settings, never bundled with Studio or printed in logs. Sent only to fanart.tv when online artist fetching is enabled.',
          style: muted,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('fanart-project-key'),
          controller: _project,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Project API key'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('fanart-personal-key'),
          controller: _personal,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Personal API key'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save keys'),
            ),
            TextButton(
              onPressed: _busy || !settings.enabled
                  ? null
                  : () => _save(remove: true),
              child: const Text('Remove keys'),
            ),
          ],
        ),
        if (_message != null) Text(_message!, style: muted),
      ],
    );
  }
}
