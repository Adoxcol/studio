import 'dart:io';

void main() {
  final file = File('lib/ui/track_actions/track_actions_menu.dart');
  var code = file.readAsStringSync();

  code = code.replaceFirst('class _NamedAction extends _TrackAction {', '''
enum _NamedActionType {
  playNow,
  playNext,
  addToQueue,
  viewAlbum,
  editMetadata,
  details,
  newPlaylist,
  remove,
}

class _NamedAction extends _TrackAction {''');

  code = code.replaceFirst('const _NamedAction(this.name);', 'const _NamedAction(this.action);');
  code = code.replaceFirst('final String name;', 'final _NamedActionType action;');

  code = code.replaceAll("_NamedAction('play-now')", "_NamedAction(_NamedActionType.playNow)");
  code = code.replaceAll("_NamedAction('play-next')", "_NamedAction(_NamedActionType.playNext)");
  code = code.replaceAll("_NamedAction('add-to-queue')", "_NamedAction(_NamedActionType.addToQueue)");
  code = code.replaceAll("_NamedAction('view-album')", "_NamedAction(_NamedActionType.viewAlbum)");
  code = code.replaceAll("_NamedAction('edit-metadata')", "_NamedAction(_NamedActionType.editMetadata)");
  code = code.replaceAll("_NamedAction('details')", "_NamedAction(_NamedActionType.details)");
  code = code.replaceAll("_NamedAction('new-playlist')", "_NamedAction(_NamedActionType.newPlaylist)");
  code = code.replaceAll("_NamedAction('remove')", "_NamedAction(_NamedActionType.remove)");

  code = code.replaceAll("_NamedAction(name: 'play-now')", "_NamedAction(action: _NamedActionType.playNow)");
  code = code.replaceAll("_NamedAction(name: 'play-next')", "_NamedAction(action: _NamedActionType.playNext)");
  code = code.replaceAll("_NamedAction(name: 'add-to-queue')", "_NamedAction(action: _NamedActionType.addToQueue)");
  code = code.replaceAll("_NamedAction(name: 'view-album')", "_NamedAction(action: _NamedActionType.viewAlbum)");
  code = code.replaceAll("_NamedAction(name: 'edit-metadata')", "_NamedAction(action: _NamedActionType.editMetadata)");
  code = code.replaceAll("_NamedAction(name: 'details')", "_NamedAction(action: _NamedActionType.details)");
  code = code.replaceAll("_NamedAction(name: 'new-playlist')", "_NamedAction(action: _NamedActionType.newPlaylist)");
  code = code.replaceAll("_NamedAction(name: 'remove')", "_NamedAction(action: _NamedActionType.remove)");

  // Remove the dead code case
  code = code.replaceFirst('''    case _NamedAction():
      break;''', '');

  file.writeAsStringSync(code);
}
