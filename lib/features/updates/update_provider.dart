import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/updates/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(service.dispose);
  return service;
});
