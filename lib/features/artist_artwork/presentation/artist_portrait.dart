import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class ArtistPortrait extends ConsumerWidget {
  const ArtistPortrait({super.key, required this.artist, this.size = 120});
  final String artist;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref
        .watch(artistPictureProvider(artistKey(artist)))
        .value
        ?.path;
    final palette = StudioPalette.of(context);
    final placeholder = ColoredBox(
      color: palette.hairlineSoft,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: size * .7,
          color: palette.inkMutedAlt,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: '$artist portrait',
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: path == null
              ? placeholder
              : Image.file(
                  File(path),
                  key: ValueKey(path),
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round()
                      .clamp(1, 640),
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Shared by the detail tab and the artist browser's image menu.
class ArtistImageControls extends ConsumerStatefulWidget {
  const ArtistImageControls({
    super.key,
    required this.artist,
    this.compact = false,
  });
  final String artist;
  final bool compact;
  @override
  ConsumerState<ArtistImageControls> createState() =>
      _ArtistImageControlsState();
}

class _ArtistImageControlsState extends ConsumerState<ArtistImageControls> {
  bool _busy = false;

  void _showCredit(PictureCredit credit) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo credit'),
        content: SingleChildScrollView(
          child: SelectableText(
            '${credit.source}\n${credit.author}\n${credit.license}\n\n${credit.pageUrl}\n\n${credit.licenseUrl}\n\nDisplayed cropped to a circle. Artist identity from MusicBrainz${credit.source == 'Wikimedia Commons' ? ' / Wikidata' : ''}.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _act(String action) async {
    // Capture the artist and repository before a picker/dialog yields: playback
    // may move on while the native dialog is open.
    final artist = widget.artist;
    final repository = ref.read(artistPictureRepositoryProvider);
    final picker = ref.read(artistImagePickerProvider);
    setState(() => _busy = true);
    try {
      switch (action) {
        case 'choose':
          final bytes = await picker();
          if (bytes != null) await repository.setCustom(artist, bytes);
        case 'automatic':
          await repository.useAutomatic(artist);
        case 'hide':
          await repository.hide(artist);
        case 'retry':
          repository.retry(artist);
      }
    } on Object catch (error) {
      repository.log('Image action "$action" failed: $error', artist: artist);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not save this image. Try a JPG, PNG or WebP file.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(artistPictureProvider(artistKey(widget.artist)));
    final picture = result.value ?? const ArtistPicture();
    final credit = picture.path != null && !picture.isCustom
        ? picture.credit
        : null;
    final searchable = ArtistImageRequest(widget.artist).searchable;
    final online = ref.watch(
      appearanceProvider.select((s) => s.fetchArtistPictures),
    );
    final palette = StudioPalette.of(context);
    final menu = PopupMenuButton<String>(
      tooltip: 'Change image',
      enabled: !_busy,
      onSelected: (action) {
        if (action == 'credit' && credit != null) {
          _showCredit(credit);
        } else {
          _act(action);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'choose',
          child: Text('Choose from computer…'),
        ),
        if (picture.isCustom || picture.hidden)
          const PopupMenuItem(
            value: 'automatic',
            child: Text('Use automatic image'),
          ),
        if (picture.path != null)
          const PopupMenuItem(value: 'hide', child: Text('Use placeholder')),
        if (online &&
            searchable &&
            picture.needsLookup &&
            picture.lookupState != PictureLookupState.searching)
          const PopupMenuItem(value: 'retry', child: Text('Try online again')),
        if (widget.compact && credit != null)
          const PopupMenuItem(value: 'credit', child: Text('Photo credit')),
      ],
      icon: widget.compact ? const Icon(Icons.more_horiz, size: 18) : null,
      child: widget.compact
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _busy ? 'Saving image…' : 'Change image',
                style: TextStyle(color: palette.accent),
              ),
            ),
    );
    if (widget.compact) return menu;
    final status = picture.isCustom
        ? 'Your image · saved on this device'
        : picture.hidden
        ? 'Placeholder selected'
        : picture.path != null
        ? 'Photo from ${credit?.source ?? 'online cache'}'
        : result.hasError
        ? 'Could not read the image cache'
        : !searchable
        ? 'No artist metadata · choose your own image'
        : !online
        ? 'No image · online fetching is off'
        : switch (picture.lookupState) {
            PictureLookupState.searching => 'Finding an artist photo…',
            PictureLookupState.failed =>
              'Photo lookup unavailable · will retry later',
            PictureLookupState.missing =>
              'No confident photo match · choose your own image',
            PictureLookupState.idle => 'Waiting for background photo lookup',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        menu,
        Text(
          status,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        if (credit != null)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.info_outline, size: 14),
            label: const Text('Photo credit'),
            onPressed: () => _showCredit(credit),
          ),
      ],
    );
  }
}
