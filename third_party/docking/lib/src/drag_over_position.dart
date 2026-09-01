import 'package:flutter/widgets.dart';

class DragOverPosition extends ChangeNotifier {
  bool _enable = false;

  bool get enable => _enable;

  set enable(bool value) {
    if (_enable == value) return;
    _enable = value;
    notifyListeners();
  }
}
