enum CloseAction {
  background,
  quit;

  static CloseAction fromName(String? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return CloseAction.background;
  }
}

/// What the close button should do.
class ClosePreference {
  const ClosePreference({
    this.ask = true,
    this.remember = CloseAction.background,
  });

  static const defaults = ClosePreference();

  /// When true, the close button shows a dialog.
  final bool ask;
  final CloseAction remember;

  ClosePreference copyWith({bool? ask, CloseAction? remember}) {
    return ClosePreference(
      ask: ask ?? this.ask,
      remember: remember ?? this.remember,
    );
  }
}

enum CloseDecision { ask, background, quit }

/// Close hides to the tray only after the icon exists, unless the user
/// chose to quit (this time or as a remembered preference).
CloseDecision decideClose({
  required bool trayReady,
  required bool quitting,
  required ClosePreference preference,
}) {
  if (quitting || !trayReady) return CloseDecision.quit;
  if (preference.ask) return CloseDecision.ask;
  return switch (preference.remember) {
    CloseAction.background => CloseDecision.background,
    CloseAction.quit => CloseDecision.quit,
  };
}

class CloseWindowChoice {
  const CloseWindowChoice({required this.action, required this.remember});

  final CloseAction action;
  final bool remember;
}
