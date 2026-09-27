// The former remote browser helpers remain available for future server tools.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_panel.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/theming/studio_palette.dart';

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.config,
    required this.connection,
    required this.trackCount,
    required this.scanState,
    required this.palette,
    required this.onScan,
    required this.onCancelScan,
    required this.onDisconnect,
    required this.onClearCache,
  });

  final SubsonicServerConfig config;
  final SubsonicConnectionInfo connection;
  final int trackCount;
  final SubsonicScanState scanState;
  final StudioPalette palette;
  final VoidCallback onScan;
  final VoidCallback onCancelScan;
  final VoidCallback onDisconnect;
  final Future<void> Function() onClearCache;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: palette.hairline),
        color: palette.hairlineSoft.withAlpha(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: palette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  config.serverName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Disconnect server',
                onPressed: onDisconnect,
                icon: const Icon(Icons.power_settings_new),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(config.normalizedUrl, style: TextStyle(color: palette.inkMuted)),
          const SizedBox(height: 4),
          Text(
            '${connection.serverType} ${connection.serverVersion} · $trackCount tracks cached',
            style: TextStyle(fontSize: 12, color: palette.inkMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: scanState.isScanning ? onCancelScan : onScan,
                icon: Icon(scanState.isScanning ? Icons.close : Icons.sync),
                label: Text(
                  scanState.isScanning ? 'Cancel scan' : 'Scan library',
                ),
              ),
              OutlinedButton.icon(
                onPressed: trackCount == 0 ? null : onClearCache,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear cached tracks'),
              ),
            ],
          ),
          if (scanState.isScanning) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: scanState.progress),
            const SizedBox(height: 6),
            Text(
              scanState.statusMessage ??
                  (scanState.totalAlbums > 0
                      ? 'Scanning album ${scanState.currentAlbum} of ${scanState.totalAlbums}'
                      : 'Scanning server...'),
              style: TextStyle(fontSize: 12, color: palette.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class SubsonicPage extends ConsumerStatefulWidget {
  const SubsonicPage({super.key});

  @override
  ConsumerState<SubsonicPage> createState() => _SubsonicPageState();
}

class _SubsonicPageState extends ConsumerState<SubsonicPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = ref.read(subsonicConfigProvider);
    if (config != null) {
      _urlController.text = config.serverUrl;
      _userController.text = config.username;
      _passController.text = config.password;
      _nameController.text = config.serverName;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _connect() {
    final config = SubsonicServerConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text,
      serverName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Navidrome',
    );
    ref.read(subsonicConfigProvider.notifier).updateConfig(config);
  }

  void _disconnect() {
    ref.read(subsonicPlaybackServiceProvider).clearSubsonicCache();
    ref.read(subsonicConfigProvider.notifier).updateConfig(null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final config = ref.watch(subsonicConfigProvider);
    final connection = ref.watch(subsonicConnectionProvider);

    if (config == null || !connection.isConnected) {
      return _buildSetupView(context, palette, connection);
    }

    return _buildConnectedView(context, palette, connection);
  }

  Widget _buildSetupView(
    BuildContext context,
    StudioPalette palette,
    SubsonicConnectionInfo connection,
  ) {
    final spectral = GoogleFonts.spectral(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      color: palette.ink,
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: palette.bg,
              border: Border.all(color: palette.hairline),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_outlined,
                        color: palette.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote Music Server', style: spectral),
                        Text(
                          'Subsonic / Navidrome / Airsonic / LMS',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect to your remote music server to stream your collection. Remote tracks remain strictly isolated from your local library catalogue.',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.inkMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (connection.status == SubsonicConnectionStatus.error &&
                    connection.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.accentPressed.withAlpha(30),
                      border: Border.all(color: palette.accentPressed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: palette.accentPressed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            connection.errorMessage!,
                            style: TextStyle(fontSize: 12, color: palette.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildField(
                  label: 'SERVER URL',
                  controller: _urlController,
                  hint: 'https://music.example.com or http://192.168.1.10:4533',
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'USERNAME',
                  controller: _userController,
                  hint: 'username',
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'PASSWORD',
                  controller: _passController,
                  hint: '••••••••',
                  obscure: true,
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'SERVER NAME (OPTIONAL)',
                  controller: _nameController,
                  hint: 'Home Navidrome',
                  palette: palette,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed:
                        connection.status == SubsonicConnectionStatus.connecting
                        ? null
                        : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.ink,
                      foregroundColor: palette.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        connection.status == SubsonicConnectionStatus.connecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Connect to Server',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required StudioPalette palette,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: palette.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(fontSize: 13, color: palette.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: palette.inkDim),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: palette.hairlineSoft.withAlpha(40),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: palette.hairline),
              borderRadius: BorderRadius.circular(6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: palette.accent),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView(
    BuildContext context,
    StudioPalette palette,
    SubsonicConnectionInfo connection,
  ) {
    final scanState = ref.watch(subsonicScanProvider);
    final tracks = ref.watch(subsonicTracksProvider).value ?? const [];
    final config = ref.watch(subsonicConfigProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONNECTED SERVERS',
            style: GoogleFonts.workSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: palette.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (config != null)
            _ServerCard(
              config: config,
              connection: connection,
              trackCount: tracks.length,
              scanState: scanState,
              palette: palette,
              onScan: () => ref.read(subsonicScanProvider.notifier).startScan(),
              onCancelScan: () =>
                  ref.read(subsonicScanProvider.notifier).cancelScan(),
              onDisconnect: _disconnect,
              onClearCache: () => ref
                  .read(subsonicPlaybackServiceProvider)
                  .clearSubsonicCache(),
            ),
          const SizedBox(height: 24),
          const SubsonicOfflinePanel(),
          const SizedBox(height: 24),
          Text(
            'This server is available as a folder in the main Library. Open Library > Folders to browse it with the same search, sorting, filters, and playback controls as local folders.',
            style: TextStyle(color: palette.inkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
