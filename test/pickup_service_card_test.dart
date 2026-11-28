import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laudry_app/features/pickup_delivery/widgets/pickup_service_card.dart';

const _short = ('Sandals', 'Prices starts from 199rs only');
const _note = ('Wash & Fold', 'Prices starts from 89rs only\nNote : Minimum 4kg');
const _long = (
  'Wash and fold ( Duvet & Bulky items )',
  'Prices starts from 49 only\nNote : House hold items',
);
const _huge = (
  'Premium delicate silk, wool and designer garment care with hand finishing',
  'A very long description that keeps going and going so that it must be cut off '
      'after two lines on every device we support\n'
      'Note : Minimum four kilograms, excluding leather, suede and heavily beaded items',
);
const _all = [_short, _note, _long, _huge];

Widget _app({
  required double width,
  double textScale = 1,
  bool selected = false,
  bool pending = false,
  List<(String, String)> items = _all,
  VoidCallback? onAdd,
  VoidCallback? onRemove,
  String? fontFamily,
}) {
  return MaterialApp(
    theme: ThemeData(fontFamily: fontFamily),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final (name, description) in items)
                    PickupServiceCard(
                      key: ValueKey(name),
                      name: name,
                      description: description,
                      imageUrl: null,
                      fallbackIcon: Icons.local_laundry_service_rounded,
                      selected: selected,
                      pending: pending,
                      onAdd: onAdd ?? () {},
                      onRemove: onRemove ?? () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Loads Roboto from the Flutter SDK so text measures like it does on a device.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
    final bytes = File('$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void _useScreen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Card height excluding the 10px bottom margin.
double _height(WidgetTester t, String name) => t.getSize(find.byKey(ValueKey(name))).height - 10;

Finder _buttonBox(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first;

void main() {
  setUpAll(_loadRoboto);

  test('note is separated from the description for display', () {
    expect(PickupServiceCard.splitNote('From 89\nNote : Minimum 4kg'), ('From 89', 'Note : Minimum 4kg'));
    expect(PickupServiceCard.splitNote('From 89 NOTE: x'), ('From 89', 'NOTE: x'));
    expect(PickupServiceCard.splitNote('Footnotes included'), ('Footnotes included', null));
    expect(PickupServiceCard.splitNote(''), ('', null));
  });

  // Small / standard / large Android, and iPhone SE → Pro Max widths.
  for (final width in [320.0, 360.0, 375.0, 393.0, 412.0, 430.0, 480.0]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('no overflow at ${width.toInt()}dp, text x$scale', (tester) async {
        _useScreen(tester, width);
        for (final selected in [false, true]) {
          await tester.pumpWidget(_app(width: width, textScale: scale, selected: selected));
          expect(tester.takeException(), isNull);
          for (final (name, _) in _all) {
            expect(_height(tester, name), greaterThanOrEqualTo(PickupServiceCard.minHeight));
          }
          // Buttons never leave the screen.
          final label = selected ? 'REMOVE' : 'ADD';
          for (var i = 0; i < _all.length; i++) {
            final r = tester.getRect(find.text(label).at(i));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(width));
          }
        }
      });
    }
  }

  for (final width in [360.0, 375.0, 393.0, 412.0, 430.0]) {
    testWidgets('typical cards are exactly equal height at ${width.toInt()}dp', (tester) async {
      _useScreen(tester, width);
      await tester.pumpWidget(
        _app(width: width, items: const [_short, _note, _long], fontFamily: 'Roboto'),
      );
      final heights = [_short, _note, _long].map((i) => _height(tester, i.$1)).toList();
      // ignore: avoid_print
      print('$width dp heights: $heights');
      expect(heights.toSet(), {PickupServiceCard.minHeight});
    });
  }

  testWidgets('ADD, REMOVE and loading share one box; nothing shifts', (tester) async {
    _useScreen(tester, 360);
    Future<(Size, Rect, double)> measure(String label) async => (
          tester.getSize(_buttonBox(label)),
          tester.getRect(find.text(_long.$1)),
          _height(tester, _long.$1),
        );

    await tester.pumpWidget(_app(width: 360, items: const [_long]));
    final add = await measure('ADD');
    await tester.pumpWidget(_app(width: 360, items: const [_long], selected: true));
    final remove = await measure('REMOVE');
    expect(remove, add);

    await tester.pumpWidget(_app(width: 360, items: const [_long], pending: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getRect(find.text(_long.$1)), add.$2);
    expect(_height(tester, _long.$1), add.$3);
  });

  testWidgets('image area fills the full card height at a fixed width', (tester) async {
    _useScreen(tester, 360);
    for (final item in _all) {
      await tester.pumpWidget(_app(width: 360, textScale: 1.6, items: [item]));
      final area = tester.getSize(
        find.descendant(of: find.byType(Positioned), matching: find.byType(ColoredBox)).first,
      );
      expect(area.width, 72); // 360dp screen → 328dp card → compact image
      expect(area.height, closeTo(_height(tester, item.$1), 0.01));
    }
  });

  testWidgets('tapping calls the matching action; loading ignores taps', (tester) async {
    _useScreen(tester, 360);
    var added = 0, removed = 0;
    Widget build({bool selected = false, bool pending = false}) => _app(
          width: 360,
          items: const [_short],
          selected: selected,
          pending: pending,
          onAdd: () => added++,
          onRemove: () => removed++,
        );
    await tester.pumpWidget(build());
    await tester.tap(find.text('ADD'));
    await tester.pumpWidget(build(selected: true));
    await tester.tap(find.text('REMOVE'));
    await tester.pumpWidget(build(pending: true));
    await tester.tap(find.byType(CircularProgressIndicator));
    expect((added, removed), (1, 1));
  });
}
