part of 'library_page.dart';

class _LibraryFilterDialog extends StatefulWidget {
  const _LibraryFilterDialog({
    required this.initial,
    required this.tracks,
    required this.folders,
  });

  final LibraryTrackFilters initial;
  final List<Track> tracks;
  final List<LibraryFolder> folders;

  @override
  State<_LibraryFilterDialog> createState() => _LibraryFilterDialogState();
}

class _LibraryFilterDialogState extends State<_LibraryFilterDialog> {
  late bool _lossless = widget.initial.losslessOnly;
  late int? _sampleRate = widget.initial.minimumSampleRateHz;
  late int? _bitrate = widget.initial.minimumBitrateKbps;
  late String? _genre = widget.initial.genre;
  late int? _year = widget.initial.year;
  late int? _folderId = widget.initial.folderId;

  late final List<String> _genres = {
    for (final track in widget.tracks) LibraryQuery.genreName(track),
  }.toList()..sort(LibraryQuery.compareText);

  late final List<int> _years = {
    for (final track in widget.tracks)
      if ((track.year ?? 0) > 0) track.year!,
  }.toList()..sort((a, b) => b.compareTo(a));

  LibraryTrackFilters get _value => LibraryTrackFilters(
    losslessOnly: _lossless,
    minimumSampleRateHz: _sampleRate,
    minimumBitrateKbps: _bitrate,
    genre: _genre,
    year: _year,
    folderId: _folderId,
  );

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return AlertDialog(
      key: const ValueKey('library-filter-dialog'),
      backgroundColor: palette.bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: palette.hairline),
      ),
      title: Text(
        'Filter library',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lossless only'),
                subtitle: const Text('FLAC, ALAC, WAV and AIFF'),
                value: _lossless,
                onChanged: (value) => setState(() => _lossless = value),
              ),
              _FilterDropdown<int>(
                label: 'Minimum sample rate',
                value: _sampleRate,
                choices: const {
                  44100: '44.1 kHz',
                  48000: '48 kHz',
                  88200: '88.2 kHz',
                  96000: '96 kHz',
                  192000: '192 kHz',
                },
                onChanged: (value) => setState(() => _sampleRate = value),
              ),
              _FilterDropdown<int>(
                label: 'Minimum estimated bitrate',
                value: _bitrate,
                choices: const {
                  256: '256 kbps',
                  320: '320 kbps',
                  500: '500 kbps',
                  1000: '1000 kbps',
                },
                onChanged: (value) => setState(() => _bitrate = value),
              ),
              _FilterDropdown<String>(
                label: 'Genre',
                value: _genre,
                choices: {for (final genre in _genres) genre: genre},
                onChanged: (value) => setState(() => _genre = value),
              ),
              _FilterDropdown<int>(
                label: 'Year',
                value: _year,
                choices: {for (final year in _years) year: '$year'},
                onChanged: (value) => setState(() => _year = value),
              ),
              _FilterDropdown<int>(
                label: 'Folder',
                value: _folderId,
                choices: {
                  for (final folder in widget.folders) folder.id: folder.path,
                },
                onChanged: (value) => setState(() => _folderId = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        LibraryTextAction(
          label: 'Clear',
          muted: true,
          onTap: () => Navigator.pop(context, const LibraryTrackFilters()),
        ),
        LibraryTextAction(
          label: 'Cancel',
          muted: true,
          onTap: () => Navigator.pop(context),
        ),
        LibraryTextAction(
          label: 'Apply',
          onTap: () => Navigator.pop(context, _value),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> choices;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(value: null, child: const Text('Any')),
        for (final entry in choices.entries)
          DropdownMenuItem<T?>(
            value: entry.key,
            child: Text(
              entry.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
