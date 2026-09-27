import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/command_palette/domain/palette_command.dart';
import 'package:studio/features/command_palette/presentation/palette_commands.dart';
import 'package:studio/theming/studio_palette.dart';

var _open = false;

/// Opens the command palette unless it is already showing.
Future<void> showCommandPalette(BuildContext context) async {
  if (_open) return;
  _open = true;
  try {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => const CommandPalette(),
    );
  } finally {
    _open = false;
  }
}

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  late final List<PaletteCommand> _commands;
  List<PaletteCommand> _results = const [];
  var _selected = 0;

  static const _rowHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _commands = buildPaletteCommands(ref);
    _results = rankCommands('', _commands);
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _results = rankCommands(value, _commands);
      _selected = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % _results.length;
    });
    if (!_scroll.hasClients) return;
    final top = _selected * _rowHeight;
    final viewport = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + _rowHeight > _scroll.offset + viewport) {
      _scroll.jumpTo(top + _rowHeight - viewport);
    }
  }

  void _run(PaletteCommand command) {
    Navigator.of(context).pop();
    command.run();
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    return Align(
      alignment: const Alignment(0, -0.6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 460),
        child: Material(
          color: palette.bg,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: palette.hairline),
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1),
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (_results.isNotEmpty) _run(_results[_selected]);
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    key: const ValueKey('command-palette-query'),
                    controller: _query,
                    autofocus: true,
                    onChanged: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search artists, albums, tracks, playlists…',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Divider(height: 1, color: palette.hairline),
                Flexible(
                  child: _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No matches', style: muted),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          itemExtent: _rowHeight,
                          itemCount: _results.length,
                          itemBuilder: (context, i) => _ResultRow(
                            command: _results[i],
                            selected: i == _selected,
                            onTap: () => _run(_results[i]),
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
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.command,
    required this.selected,
    required this.onTap,
  });

  final PaletteCommand command;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    PaletteKind.screen: Icons.arrow_forward,
    PaletteKind.action: Icons.bolt,
    PaletteKind.artist: Icons.person_outline,
    PaletteKind.album: Icons.album_outlined,
    PaletteKind.playlist: Icons.queue_music,
    PaletteKind.track: Icons.music_note_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final subtitle = command.subtitle;
    return Semantics(
      button: true,
      selected: selected,
      label: '${command.kind.label}: ${command.title}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? palette.accent.withAlpha(28) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                _icons[command.kind],
                size: 18,
                color: selected ? palette.accent : palette.inkMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: command.title,
                        style: theme.bodyMedium?.copyWith(color: palette.ink),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        TextSpan(
                          text: '  $subtitle',
                          style: theme.bodySmall?.copyWith(
                            color: palette.inkMuted,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                command.shortcut ?? command.kind.label,
                style: theme.labelSmall?.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
