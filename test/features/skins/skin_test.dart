import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/skins/data/skin_store.dart';
import 'package:studio/features/skins/domain/skin.dart';
import 'package:studio/features/skins/presentation/skins_panel.dart';
import 'package:studio/features/skins/presentation/skins_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/theming/studio_theme.dart';

String skinJson({
  String name = 'Midnight Paper',
  Object? light,
  Object? dark,
  Object? extra,
}) => jsonEncode({
  'format': 'studio-skin',
  'version': 1,
  'name': name,
  'author': 'Rob',
  'light': light ?? {'bg': '#FFFFFF', 'ink': '#101010', 'unknown': '#FF0000'},
  'dark': dark ?? {'bg': '#0A0A14', 'ink': '#F0F0FF'},
  if (extra is Map) ...extra,
});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Skin.parse', () {
    test('reads overrides and ignores unknown tokens', () {
      final skin = Skin.parse(skinJson());
      expect(skin.name, 'Midnight Paper');
      expect(skin.author, 'Rob');
      expect(skin.light.colors.keys, unorderedEquals(['bg', 'ink']));
      expect(skin.dark.colors['bg'], const Color(0xFF0A0A14));
    });

    test('missing tokens keep the built-in palette', () {
      final skin = Skin.parse(skinJson());
      final base = StudioPalette.light();
      final applied = skin.light.applyTo(base);
      expect(applied.bg, const Color(0xFFFFFFFF));
      expect(applied.hairline, base.hairline);
      expect(applied.accent, base.accent);
    });

    test('round-trips through encode with a stable id', () {
      final skin = Skin.parse(skinJson(extra: {'accentHue': 400}));
      expect(skin.accentHue, 40);
      final again = Skin.parse(skin.encode());
      expect(again.id, skin.id);
      expect(again.id, startsWith('midnight-paper-'));
      expect(again.encode(), skin.encode());
    });

    test('rejects files that are not valid skins', () {
      Matcher fails(String text) => throwsA(
        isA<SkinFormatException>().having(
          (e) => e.message,
          'message',
          contains(text),
        ),
      );
      expect(() => Skin.parse('nope'), fails('not a valid skin'));
      expect(
        () => Skin.parse('{"format":"other"}'),
        fails('not a Studio skin'),
      );
      expect(
        () => Skin.parse(
          jsonEncode({'format': 'studio-skin', 'version': 2, 'name': 'x'}),
        ),
        fails('different version'),
      );
      expect(() => Skin.parse(skinJson(name: '  ')), fails('needs a name'));
      expect(
        () => Skin.parse(skinJson(light: {'bg': 'red'})),
        fails('light.bg must be a colour'),
      );
      expect(
        () => Skin.parse(skinJson(light: {'bg': '#FFFFFF80'})),
        fails('light.bg must be a colour'),
      );
      expect(() => Skin.parse(' ' * (Skin.maxBytes + 1)), fails('64 KB'));
    });

    test('rejects unreadable text in either mode', () {
      expect(
        () => Skin.parse(skinJson(light: {'bg': '#FFFFFF', 'ink': '#DDDDDD'})),
        throwsA(
          isA<SkinFormatException>().having(
            (e) => e.message,
            'message',
            contains('light palette is too hard to read'),
          ),
        ),
      );
      expect(
        () => Skin.parse(skinJson(dark: {'inkMuted': '#1A1816'})),
        throwsA(isA<SkinFormatException>()),
      );
    });
  });

  test('contrast ratio follows WCAG', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFF777777)),
      closeTo(1, 0.01),
    );
    expect(hexOf(const Color(0xFF0a0b0c)), '#0A0B0C');
  });

  test('the theme and window background use the skin', () {
    final skin = Skin.parse(skinJson());
    final theme = StudioTheme.dark(skin: skin.dark);
    expect(theme.extension<StudioPalette>()!.bg, const Color(0xFF0A0A14));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0A14));
    expect(
      StudioTheme.windowBackground(AppThemeMode.light, skin: skin),
      const Color(0xFFFFFFFF),
    );
  });

  test('file store installs, lists, activates and removes', () {
    final dir = Directory.systemTemp.createTempSync('studio-skins');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FileSkinStore(dir);
    final skin = Skin.parse(skinJson());
    store.install(skin);
    File(p.join(dir.path, 'broken.studioskin')).writeAsStringSync('{');
    store.saveActive(skin.id);
    final reopened = FileSkinStore(dir);
    expect(reopened.load().map((s) => s.id), [skin.id]);
    expect(reopened.loadActive(), skin.id);
    reopened.remove(skin.id);
    expect(reopened.load(), isEmpty);
  });

  group('skinsProvider', () {
    late ProviderContainer container;
    late MemorySkinStore store;

    setUp(() {
      store = MemorySkinStore();
      container = ProviderContainer(
        overrides: [skinStoreProvider.overrideWithValue(store)],
      );
    });
    tearDown(() => container.dispose());

    test('import installs, applies and adopts the suggested hue', () {
      final skin = container
          .read(skinsProvider.notifier)
          .import(skinJson(extra: {'accentHue': 200}));
      expect(container.read(activeSkinProvider)?.id, skin.id);
      expect(store.active, skin.id);
      final appearance = container.read(appearanceProvider);
      expect(appearance.mode, AccentMode.custom);
      expect(appearance.customHue, 200);
    });

    test('removing the active skin returns to Editorial', () {
      final notifier = container.read(skinsProvider.notifier);
      final skin = notifier.import(skinJson());
      notifier.remove(skin.id);
      expect(container.read(activeSkinProvider), isNull);
      expect(container.read(skinsProvider).skins, isEmpty);
      expect(store.active, isNull);
    });

    test('Editorial exports as a complete, valid skin', () {
      final exported = container.read(skinsProvider.notifier).exportable();
      final parsed = Skin.parse(exported.encode());
      expect(parsed.name, 'Editorial');
      expect(parsed.light.colors.keys, unorderedEquals(skinTokens));
      expect(
        parsed.dark.applyTo(StudioPalette.dark()).bg,
        StudioPalette.dark().bg,
      );
    });

    test('an unknown saved id falls back to Editorial', () {
      store.active = 'gone';
      expect(container.read(activeSkinProvider), isNull);
    });
  });

  group('SkinsPanel', () {
    Future<void> pump(
      WidgetTester tester, {
      required Future<String?> Function() pick,
      Future<bool> Function(String, String)? save,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [skinStoreProvider.overrideWithValue(MemorySkinStore())],
          child: MaterialApp(
            theme: StudioTheme.light(),
            home: Scaffold(
              body: SkinsPanel(pickSkinText: pick, saveSkinFile: save),
            ),
          ),
        ),
      );
    }

    testWidgets('imports a skin and lists it as active', (tester) async {
      await pump(tester, pick: () async => skinJson());
      await tester.tap(find.byKey(const ValueKey('skin-import')));
      await tester.pumpAndSettle();
      expect(
        find.text('Installed and applied “Midnight Paper”.'),
        findsOneWidget,
      );
      expect(find.text('Midnight Paper · Rob'), findsOneWidget);
      expect(find.byTooltip('Remove Midnight Paper'), findsOneWidget);
    });

    testWidgets('explains why a skin was refused', (tester) async {
      await pump(tester, pick: () async => '{"format":"nope"}');
      await tester.tap(find.byKey(const ValueKey('skin-import')));
      await tester.pumpAndSettle();
      expect(find.text('This is not a Studio skin file.'), findsOneWidget);
    });

    testWidgets('exports the current look', (tester) async {
      String? savedName;
      String? savedContents;
      await pump(
        tester,
        pick: () async => null,
        save: (name, contents) async {
          savedName = name;
          savedContents = contents;
          return true;
        },
      );
      await tester.tap(find.byKey(const ValueKey('skin-export')));
      await tester.pumpAndSettle();
      expect(savedName, 'editorial.studioskin');
      expect(Skin.parse(savedContents!).name, 'Editorial');
      expect(find.text('Exported “Editorial”.'), findsOneWidget);
    });
  });
}
