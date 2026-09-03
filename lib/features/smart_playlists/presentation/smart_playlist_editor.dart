import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_palette.dart';

Future<int?> showSmartPlaylistEditor({
  required BuildContext context,
  Playlist? playlist,
  SmartPlaylistDefinition? initial,
}) async {
  if (playlist?.smartRules case final rules?) {
    try {
      initial = SmartPlaylistDefinition.decode(rules);
    } on Object catch (error) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot open playlist rules'),
          content: Text(
            'The saved rules could not be read. They have not been changed.\n$error',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return null;
    }
  }
  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SmartPlaylistEditor(playlist: playlist, initial: initial),
  );
}

class _SmartPlaylistEditor extends ConsumerStatefulWidget {
  const _SmartPlaylistEditor({this.playlist, this.initial});
  final Playlist? playlist;
  final SmartPlaylistDefinition? initial;
  @override
  ConsumerState<_SmartPlaylistEditor> createState() =>
      _SmartPlaylistEditorState();
}

class _SmartPlaylistEditorState extends ConsumerState<_SmartPlaylistEditor> {
  late final _name = TextEditingController(text: widget.playlist?.name ?? '');
  late final _rules =
      (widget.initial?.rules ??
              const [SmartRule(SmartField.genre, SmartOperator.contains, '')])
          .map(_RuleDraft.new)
          .toList();
  late bool _matchAll = widget.initial?.matchAll ?? true;
  late LibrarySort _sort = widget.initial?.sort ?? LibrarySort.title;
  late LibraryOrder _order = widget.initial?.order ?? LibraryOrder.ascending;
  bool _saving = false;
  String? _error;

  SmartPlaylistDefinition get _definition => SmartPlaylistDefinition(
    rules: _rules.map((rule) => rule.rule).toList(),
    matchAll: _matchAll,
    sort: _sort,
    order: _order,
  );

  @override
  void dispose() {
    _name.dispose();
    for (final rule in _rules) {
      rule.value.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final definition = _definition;
    if (_name.text.trim().isEmpty || definition.validate() != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = ref.read(studioDatabaseProvider);
      final id = widget.playlist?.id;
      if (id != null) {
        await db.updateSmartPlaylist(id, _name.text, definition.encode());
        if (mounted) Navigator.pop(context, id);
      } else {
        final created = await db.createPlaylist(
          _name.text,
          smartRules: definition.encode(),
        );
        if (mounted) Navigator.pop(context, created);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the playlist.\n$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final definition = _definition;
    final invalid = definition.validate();
    final library = ref.watch(libraryTracksProvider);
    final matches = definition.evaluate(library.value ?? const []);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const ValueKey('smart-playlist-editor'),
        backgroundColor: palette.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: palette.hairline),
        ),
        title: Text(
          widget.playlist == null
              ? 'New smart playlist'
              : 'Edit smart playlist',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('smart-playlist-name'),
                  controller: _name,
                  enabled: !_saving,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: _input(context, 'Name'),
                ),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      'Match',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    DropdownButton<bool>(
                      value: _matchAll,
                      items: const [
                        DropdownMenuItem(value: true, child: Text('all rules')),
                        DropdownMenuItem(value: false, child: Text('any rule')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _matchAll = value!),
                    ),
                    TextButton(
                      key: const ValueKey('smart-add-rule'),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _rules.add(
                                _RuleDraft(
                                  const SmartRule(
                                    SmartField.genre,
                                    SmartOperator.contains,
                                    '',
                                  ),
                                ),
                              );
                            }),
                      child: const Text('Add rule'),
                    ),
                  ],
                ),
                for (final draft in _rules)
                  _RuleEditor(
                    key: ObjectKey(draft),
                    draft: draft,
                    enabled: !_saving,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() {
                      _rules.remove(draft);
                      draft.value.dispose();
                    }),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Sort by'),
                    DropdownButton<LibrarySort>(
                      value: _sort,
                      items: [
                        for (final sort in LibrarySort.values)
                          DropdownMenuItem(value: sort, child: Text(sort.name)),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _sort = value!),
                    ),
                    DropdownButton<LibraryOrder>(
                      value: _order,
                      items: [
                        for (final order in LibraryOrder.values)
                          DropdownMenuItem(
                            value: order,
                            child: Text(order.name),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _order = value!),
                    ),
                  ],
                ),
                Divider(color: palette.hairline, height: 28),
                Text(
                  invalid ??
                      (library.hasError
                          ? 'Library preview is unavailable.'
                          : library.isLoading
                          ? 'Loading preview…'
                          : '${matches.length} matching ${matches.length == 1 ? 'track' : 'tracks'}'),
                  key: const ValueKey('smart-preview-count'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: invalid != null ? palette.inkMuted : palette.accent,
                  ),
                ),
                if (invalid == null) ...[
                  const SizedBox(height: 8),
                  for (final track in matches.take(4))
                    Text(
                      '${track.title} — ${track.artist ?? 'Unknown artist'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Updates automatically as your library changes. Bitrate is estimated from file size and duration; lossless matching uses the file format.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: palette.accent)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('save-smart-playlist'),
            onPressed: _saving || invalid != null || _name.text.trim().isEmpty
                ? null
                : _save,
            child: Text(_saving ? 'Saving…' : 'Save playlist'),
          ),
        ],
      ),
    );
  }
}

class _RuleDraft {
  _RuleDraft(SmartRule rule)
    : field = rule.field,
      operator = rule.operator,
      value = TextEditingController(text: rule.value);
  SmartField field;
  SmartOperator operator;
  final TextEditingController value;
  SmartRule get rule => SmartRule(field, operator, value.text);
}

class _RuleEditor extends ConsumerWidget {
  const _RuleEditor({
    super.key,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });
  final _RuleDraft draft;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = draft.field == SmartField.folder
        ? ref.watch(libraryFoldersProvider).value ?? const <LibraryFolder>[]
        : const <LibraryFolder>[];
    final folderId = int.tryParse(draft.value.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButton<SmartField>(
                  isExpanded: true,
                  value: draft.field,
                  items: [
                    for (final field in SmartField.values)
                      DropdownMenuItem(
                        value: field,
                        child: Text(
                          field.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: !enabled
                      ? null
                      : (field) {
                          draft.field = field!;
                          draft.operator = field.operators.first;
                          draft.value.text = field == SmartField.lossless
                              ? 'true'
                              : '';
                          onChanged();
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<SmartOperator>(
                  isExpanded: true,
                  value: draft.operator,
                  items: [
                    for (final op in draft.field.operators)
                      DropdownMenuItem(value: op, child: Text(op.label)),
                  ],
                  onChanged: !enabled
                      ? null
                      : (op) {
                          draft.operator = op!;
                          onChanged();
                        },
                ),
              ),
              IconButton(
                tooltip: 'Remove rule',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          if (draft.field == SmartField.folder)
            DropdownButton<int>(
              isExpanded: true,
              hint: const Text('Choose a library folder'),
              value: folderId,
              items: [
                for (final folder in folders)
                  DropdownMenuItem(
                    value: folder.id,
                    child: Text(folder.path, overflow: TextOverflow.ellipsis),
                  ),
                if (folderId != null &&
                    !folders.any((folder) => folder.id == folderId))
                  DropdownMenuItem(
                    value: folderId,
                    child: Text('Unavailable folder ($folderId)'),
                  ),
              ],
              onChanged: !enabled
                  ? null
                  : (value) {
                      draft.value.text = '$value';
                      onChanged();
                    },
            )
          else if (draft.field == SmartField.lossless)
            DropdownButton<bool>(
              isExpanded: true,
              value: draft.value.text == 'true',
              items: const [
                DropdownMenuItem(value: true, child: Text('Yes')),
                DropdownMenuItem(value: false, child: Text('No')),
              ],
              onChanged: !enabled
                  ? null
                  : (value) {
                      draft.value.text = '$value';
                      onChanged();
                    },
            )
          else
            TextField(
              controller: draft.value,
              enabled: enabled,
              onChanged: (_) => onChanged(),
              keyboardType: draft.field.numeric
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: _input(
                context,
                draft.field == SmartField.format ? 'Value, e.g. flac' : 'Value',
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _input(BuildContext context, String label) {
  final palette = StudioPalette.of(context);
  return InputDecoration(
    labelText: label,
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: palette.hairline),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: palette.accent),
    ),
  );
}
