import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/updates/update_provider.dart';

class UpdateNotice extends ConsumerStatefulWidget {
  const UpdateNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends ConsumerState<UpdateNotice> {
  var _shownVersion = '';

  @override
  Widget build(BuildContext context) {
    final service = ref.read(updateServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final update = service.state;
        if (update.ready &&
            update.version != null &&
            update.version != _shownVersion) {
          _shownVersion = update.version!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            if (messenger == null) return;
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Studio ${update.version} is ready to install.'),
                duration: const Duration(days: 1),
                action: SnackBarAction(
                  label: 'Restart and Update',
                  onPressed: service.restartAndUpdate,
                ),
              ),
            );
          });
        }
        return widget.child;
      },
    );
  }
}
