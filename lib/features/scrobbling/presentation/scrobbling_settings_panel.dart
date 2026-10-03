import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/desktop/open_url.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/presentation/scrobble_providers.dart';
import 'package:studio/theming/studio_palette.dart';

/// Appears in the Settings > Connections tab to manage API keys, log in,
/// and disconnect Last.fm and ListenBrainz.
class ScrobblingSettingsPanel extends StatelessWidget {
  const ScrobblingSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_LastFmPanel(), SizedBox(height: 24), _ListenBrainzPanel()],
    );
  }
}

String _describe(Object error) => switch (error) {
  ScrobbleException(:final failure, :final message) =>
    failure == ScrobbleFailure.retry
        ? 'Could not reach the service. Check your connection and try again.'
        : message,
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => 'Something went wrong. Try again.',
};

TextStyle? _muted(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: StudioPalette.of(context).inkMuted);

class _LastFmPanel extends ConsumerStatefulWidget {
  const _LastFmPanel();

  @override
  ConsumerState<_LastFmPanel> createState() => _LastFmPanelState();
}

class _LastFmPanelState extends ConsumerState<_LastFmPanel> {
  late final TextEditingController _key;
  late final TextEditingController _secret;
  bool _busy = false;
  bool _editingKeys = false;
  Uri? _approvalUrl;
  String? _message;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(scrobbleSettingsProvider).asData?.value;
    _key = TextEditingController(text: settings?.lastFmApiKey ?? '');
    _secret = TextEditingController(text: settings?.lastFmSecret ?? '');
  }

  @override
  void dispose() {
    _key.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
    final url = await ref
        .read(scrobbleSettingsProvider.notifier)
        .startLastFmAuth();
    final opened = await openUrl(url);
    if (!mounted) return;
    setState(() {
      _approvalUrl = url;
      _message = opened
          ? 'Approve Studio in your browser, then choose Finish connecting.'
          : 'Open the link below, approve Studio, then choose Finish connecting.';
    });
  });

  Future<void> _finish() => _run(() async {
    await ref.read(scrobbleSettingsProvider.notifier).finishLastFmAuth();
    if (mounted) setState(() => _approvalUrl = null);
  });

  void _cancel() {
    ref.read(scrobbleSettingsProvider.notifier).cancelLastFmAuth();
    setState(() {
      _approvalUrl = null;
      _message = null;
    });
  }

  void _saveKeys() {
    ref
        .read(scrobbleSettingsProvider.notifier)
        .setLastFmKeys(_key.text, _secret.text);
    setState(() {
      _editingKeys = false;
      _approvalUrl = null;
      _message = 'Keys saved. Connect your account to start scrobbling.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(scrobbleSettingsProvider);
    if (!asyncSettings.hasValue) return const SizedBox.shrink();
    final settings = asyncSettings.requireValue;
    final muted = _muted(context);
    final showKeys = _editingKeys || !settings.hasLastFmKeys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last.fm', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        if (settings.lastFmConnected) ...[
          Text(
            settings.lastFmUser.isEmpty
                ? 'Connected. Tracks are scrobbled after half their length or four minutes.'
                : 'Connected as ${settings.lastFmUser}. Tracks are scrobbled after half their length or four minutes.',
            style: muted,
          ),
          TextButton(
            key: const ValueKey('lastfm-disconnect'),
            onPressed: () =>
                ref.read(scrobbleSettingsProvider.notifier).disconnectLastFm(),
            child: const Text('Disconnect'),
          ),
        ] else ...[
          if (settings.lastFmExpired)
            Text(
              'Last.fm stopped accepting the saved session. Reconnect to resume scrobbling.',
              style: muted,
            ),
          if (showKeys) ...[
            Text(
              'Enter an API key and shared secret from last.fm/api/account/create. They are securely stored in this device’s keychain/credential vault.',
              style: muted,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lastfm-api-key'),
              controller: _key,
              enableSuggestions: false,
              autocorrect: false,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'API key'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lastfm-secret'),
              controller: _secret,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Shared secret'),
            ),
            TextButton(
              key: const ValueKey('lastfm-save-keys'),
              onPressed: _busy ? null : _saveKeys,
              child: const Text('Save keys'),
            ),
          ],
          if (settings.hasLastFmKeys && !_editingKeys)
            Wrap(
              spacing: 16,
              children: [
                if (_approvalUrl == null)
                  TextButton(
                    key: const ValueKey('lastfm-connect'),
                    onPressed: _busy ? null : _start,
                    child: Text(_busy ? 'Connecting…' : 'Connect Last.fm'),
                  )
                else ...[
                  TextButton(
                    key: const ValueKey('lastfm-finish'),
                    onPressed: _busy ? null : _finish,
                    child: Text(_busy ? 'Checking…' : 'Finish connecting'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
                if (_approvalUrl == null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _editingKeys = true),
                    child: const Text('Use my own API key'),
                  ),
              ],
            ),
          if (_approvalUrl != null)
            Row(
              children: [
                Expanded(
                  child: SelectableText(_approvalUrl.toString(), style: muted),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: _approvalUrl.toString()),
                  ),
                ),
              ],
            ),
        ],
        if (_message != null) Text(_message!, style: muted),
      ],
    );
  }
}

class _ListenBrainzPanel extends ConsumerStatefulWidget {
  const _ListenBrainzPanel();

  @override
  ConsumerState<_ListenBrainzPanel> createState() => _ListenBrainzPanelState();
}

class _ListenBrainzPanelState extends ConsumerState<_ListenBrainzPanel> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(scrobbleSettingsProvider.notifier)
          .connectListenBrainz(_token.text);
      _token.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(scrobbleSettingsProvider);
    if (!asyncSettings.hasValue) return const SizedBox.shrink();
    final settings = asyncSettings.requireValue;
    final muted = _muted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ListenBrainz', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        if (settings.listenBrainzConnected) ...[
          Text(
            settings.listenBrainzUser.isEmpty
                ? 'Connected.'
                : 'Connected as ${settings.listenBrainzUser}.',
            style: muted,
          ),
          TextButton(
            key: const ValueKey('listenbrainz-disconnect'),
            onPressed: () => ref
                .read(scrobbleSettingsProvider.notifier)
                .disconnectListenBrainz(),
            child: const Text('Disconnect'),
          ),
        ] else ...[
          if (settings.listenBrainzExpired)
            Text(
              'ListenBrainz stopped accepting the saved token. Paste it again to resume.',
              style: muted,
            ),
          Text(
            'Paste the user token from listenbrainz.org/settings. It is securely stored in this device’s keychain/credential vault.',
            style: muted,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('listenbrainz-token'),
            controller: _token,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'User token'),
          ),
          TextButton(
            key: const ValueKey('listenbrainz-connect'),
            onPressed: _busy ? null : _connect,
            child: Text(_busy ? 'Checking…' : 'Connect ListenBrainz'),
          ),
        ],
        if (_message != null) Text(_message!, style: muted),
      ],
    );
  }
}
