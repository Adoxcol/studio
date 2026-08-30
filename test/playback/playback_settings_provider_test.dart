import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/equalizer_import.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/playback/playback_settings_store.dart';
import 'package:studio/state/library_providers.dart';

import 'fake_audio_engine.dart';

void main() {
  late MemoryPlaybackSettingsStore store;
  late FakeAudioEngine engine;
  late ProviderContainer container;

  setUp(() {
    store = MemoryPlaybackSettingsStore();
    engine = FakeAudioEngine();
    container = ProviderContainer(
      overrides: [
        playbackSettingsStoreProvider.overrideWithValue(store),
        audioEngineProvider.overrideWithValue(engine),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state loads from store', () {
    store.value = PlaybackSettings.defaults.copyWith(
      replayGain: ReplayGainMode.track,
    );
    final state = container.read(playbackSettingsProvider);
    expect(state.replayGain, ReplayGainMode.track);
  });

  test('setReplayGain updates state, store, and engine', () {
    container.read(playbackSettingsProvider.notifier).setReplayGain(
      ReplayGainMode.album,
    );
    expect(
      container.read(playbackSettingsProvider).replayGain,
      ReplayGainMode.album,
    );
    expect(store.value.replayGain, ReplayGainMode.album);
    expect(engine.lastReplayGain, ReplayGainMode.album);
  });

  test('setEqualizerPreset updates state, store, and engine', () {
    container.read(playbackSettingsProvider.notifier).setEqualizerPreset(
      EqualizerPreset.rock,
    );
    final state = container.read(playbackSettingsProvider);
    expect(state.equalizerPreset, EqualizerPreset.rock);
    expect(
      state.equalizerGains,
      Equalizer.gainsFor(EqualizerPreset.rock, Equalizer.flat),
    );
    expect(state.equalizerPreamp, 0.0);

    expect(store.value.equalizerPreset, EqualizerPreset.rock);
    expect(
      store.value.equalizerGains,
      Equalizer.gainsFor(EqualizerPreset.rock, Equalizer.flat),
    );
    expect(store.value.equalizerPreamp, 0.0);

    expect(
      engine.lastEqualizer,
      Equalizer.gainsFor(EqualizerPreset.rock, Equalizer.flat),
    );
    expect(engine.lastEqualizerPreamp, 0.0);
  });

  test('setEqualizerPreset custom preserves preamp', () {
    store.value = PlaybackSettings.defaults.copyWith(
      equalizerPreamp: 5.0,
      equalizerPreset: EqualizerPreset.rock,
    );

    // Switch to rock, should reset preamp to 0
    container.read(playbackSettingsProvider.notifier).setEqualizerPreset(
      EqualizerPreset.pop,
    );
    expect(container.read(playbackSettingsProvider).equalizerPreamp, 0.0);
    expect(engine.lastEqualizerPreamp, 0.0);

    store.value = store.value.copyWith(equalizerPreamp: 4.2);
    // recreate container to reload store
    container = ProviderContainer(
      overrides: [
        playbackSettingsStoreProvider.overrideWithValue(store),
        audioEngineProvider.overrideWithValue(engine),
      ],
    );

    container.read(playbackSettingsProvider.notifier).setEqualizerPreset(
      EqualizerPreset.custom,
    );
    expect(container.read(playbackSettingsProvider).equalizerPreamp, 4.2);
    expect(engine.lastEqualizerPreamp, 4.2);
  });

  test('setEqualizerBand ignores invalid index', () {
    container.read(playbackSettingsProvider.notifier).setEqualizerBand(-1, 5.0);
    container.read(playbackSettingsProvider.notifier).setEqualizerBand(10, 5.0);
    expect(
      container.read(playbackSettingsProvider).equalizerPreset,
      EqualizerPreset.flat,
    );
  });

  test('setEqualizerBand updates band, changes to custom preset', () {
    container.read(playbackSettingsProvider.notifier).setEqualizerBand(2, 6.0);
    final state = container.read(playbackSettingsProvider);
    expect(state.equalizerPreset, EqualizerPreset.custom);
    expect(state.equalizerGains[2], 6.0);
    expect(store.value.equalizerGains[2], 6.0);
    expect(engine.lastEqualizer[2], 6.0);
  });

  test('setEqualizerBand clamps gain', () {
    container.read(playbackSettingsProvider.notifier).setEqualizerBand(
      2,
      200.0,
    );
    expect(container.read(playbackSettingsProvider).equalizerGains[2], 15.0);
    container.read(playbackSettingsProvider.notifier).setEqualizerBand(
      2,
      -200.0,
    );
    expect(container.read(playbackSettingsProvider).equalizerGains[2], -15.0);
  });

  test('importEqualizer updates state, store, and engine', () {
    final imported = ImportedEqualizer(
      gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      preamp: 5.0,
    );
    container.read(playbackSettingsProvider.notifier).importEqualizer(imported);

    final state = container.read(playbackSettingsProvider);
    expect(state.equalizerPreset, EqualizerPreset.custom);
    expect(state.equalizerGains, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(state.equalizerPreamp, 5.0);

    expect(store.value.equalizerGains, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(engine.lastEqualizer, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(engine.lastEqualizerPreamp, 5.0);
  });

  test('importEqualizer clamps preamp', () {
    final imported = ImportedEqualizer(
      gains: Equalizer.flat,
      preamp: 50.0,
    );
    container.read(playbackSettingsProvider.notifier).importEqualizer(imported);
    expect(container.read(playbackSettingsProvider).equalizerPreamp, 15.0);
  });

  test('importEqualizerText parses and applies', () {
    const text = 'Preamp: -1.5 dB\nFilter 1: ON PK Fc 32 Hz Gain 2 dB Q 1\n';
    container.read(playbackSettingsProvider.notifier).importEqualizerText(text);

    final state = container.read(playbackSettingsProvider);
    expect(state.equalizerPreset, EqualizerPreset.custom);
    expect(state.equalizerPreamp, -1.5);
    // Band 1 corresponds to 32Hz
    expect(state.equalizerGains[0], closeTo(2.0, 0.01));
  });

  test('setCrossfade updates state, store, and engine', () {
    container.read(playbackSettingsProvider.notifier).setCrossfade(
      const Duration(seconds: 2),
    );
    expect(
      container.read(playbackSettingsProvider).crossfade,
      const Duration(seconds: 2),
    );
    expect(store.value.crossfade, const Duration(seconds: 2));
    expect(engine.lastCrossfade, const Duration(seconds: 2));
  });
}
