import 'package:flutter/material.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_palette.dart';

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  String title = 'New playlist',
  String initialName = '',
  String action = 'Create',
  String? description,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(
    title: title,
    initialName: initialName,
    action: action,
    description: description,
  ),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initialName,
    required this.action,
    this.description,
  });
  final String title;
  final String initialName;
  final String action;
  final String? description;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isNotEmpty) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => _dialog(
    context,
    title: widget.title,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(widget.description!),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const ValueKey('playlist-name-field'),
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Name',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: StudioPalette.of(context).hairline,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: StudioPalette.of(context).accent),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _name.text.trim().isEmpty ? null : _submit,
        child: Text(widget.action),
      ),
    ],
  );
}

Future<bool> confirmPlaylistDeletion(
  BuildContext context,
  Playlist playlist,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _dialog(
        context,
        title: 'Delete playlist?',
        content: Text(
          'Delete “${playlist.name}”?\n\nOnly this playlist will be removed. Your music files and library tracks will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showPlaylistOrderEditor(
  BuildContext context, {
  required StudioDatabase database,
  required Playlist playlist,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _OrderDialog(database: database, playlist: playlist),
);

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.database, required this.playlist});
  final StudioDatabase database;
  final Playlist playlist;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  List<({int entryId, Track track})>? _items;
  String? _error;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.database.playlistItems(widget.playlist.id);
      if (mounted) setState(() => _items = items);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load this playlist.\n$error');
      }
    }
  }

  void _move(int from, int to) {
    if (_saving) return;
    setState(() {
      if (to > from) to--;
      _items!.insert(to, _items!.removeAt(from));
      _changed = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.database.reorderPlaylistEntries(
        widget.playlist.id,
        _items!.map((item) => item.entryId).toList(),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this order.\n$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final items = _items;
    return PopScope(
      canPop: !_saving,
      child: _dialog(
        context,
        title: 'Reorder tracks',
        content: SizedBox(
          width: 600,
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Drag the handles or use the arrows. This edits the full playlist, not just filtered tracks.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      _error!,
                      style: TextStyle(color: palette.accent),
                    ),
                  ),
                ),
              Expanded(
                child: items == null
                    ? Center(
                        child: Text(
                          _error == null
                              ? 'Loading tracks…'
                              : 'Close and try again.',
                        ),
                      )
                    : items.isEmpty
                    ? const Center(child: Text('This playlist is empty.'))
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        // Supported Flutter SDK predates onReorderItem.
                        // ignore: deprecated_member_use
                        onReorder: _move,
                        proxyDecorator: (child, _, _) =>
                            Material(color: palette.bg, child: child),
                        itemExtent: 64,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return DecoratedBox(
                            key: ValueKey(item.entryId),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: palette.hairlineSoft),
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  enabled: !_saving,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Tooltip(
                                      message: 'Drag to reorder',
                                      child: SizedBox(
                                        width: 32,
                                        height: 48,
                                        child: Icon(
                                          Icons.drag_handle,
                                          size: 18,
                                          color: palette.inkMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.track.artist ?? 'Unknown artist',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: palette.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move up',
                                  onPressed: _saving || index == 0
                                      ? null
                                      : () => _move(index, index - 1),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move down',
                                  onPressed:
                                      _saving || index == items.length - 1
                                      ? null
                                      : () => _move(index, index + 2),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _saving || !_changed ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save order'),
          ),
        ],
      ),
    );
  }
}

AlertDialog _dialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  final palette = StudioPalette.of(context);
  return AlertDialog(
    backgroundColor: palette.bg,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: palette.hairline),
    ),
    title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    content: content,
    actions: actions,
  );
}
