import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/config.dart';
import 'package:macrodash/option_buttons.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

Widget _host(Uri uri, {Map<String, String>? queryParams}) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(actions: [ShareButton(uri: uri, queryParams: queryParams)]),
  ),
);

Future<void> _openShareDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.share));
  await tester.pumpAndSettle();
}

String? _previewUrl(WidgetTester tester) {
  final images = tester.widgetList<SharePreviewImage>(
    find.byType(SharePreviewImage),
  );
  return images.isEmpty ? null : images.single.url;
}

void main() {
  group('share dialog preview image', () {
    testWidgets('shows the ticker chart image', (tester) async {
      await tester.pumpWidget(
        _host(
          Uri.parse('/ticker?ticker1=GC%3DF&title=Gold'),
          queryParams: {'ticker1': 'GC=F', 'title': 'Gold'},
        ),
      );
      await _openShareDialog(tester);

      expect(
        _previewUrl(tester),
        tickerPreviewImageUrl(
          previewUrl: resolvedLinkPreviewUrl,
          ticker1: 'GC=F',
          params: {'title': 'Gold'},
        ),
      );
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('shows the page chart image', (tester) async {
      await tester.pumpWidget(
        _host(Uri.parse('/marketCap'), queryParams: {'market': 'stocks'}),
      );
      await _openShareDialog(tester);

      expect(
        _previewUrl(tester),
        pagePreviewImageUrl(
          previewUrl: resolvedLinkPreviewUrl,
          page: 'marketCap',
          params: {'market': 'stocks'},
        ),
      );
    });

    testWidgets('omits the image for pages without a preview', (tester) async {
      await tester.pumpWidget(_host(Uri.parse('/settings')));
      await _openShareDialog(tester);

      expect(find.byType(SharePreviewImage), findsNothing);
      // The link itself is still offered.
      expect(find.textContaining('#/settings'), findsOneWidget);
    });

    testWidgets('falls back to a placeholder when the image fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(Uri.parse('/m2'), queryParams: {'region': 'usa'}),
      );
      await _openShareDialog(tester);

      // Tests have no network, so the request fails and the error state shows.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Preview unavailable'), findsOneWidget);
    });
  });

  group('SharePreviewImage', () {
    testWidgets('shows a spinner until the first frame is decoded', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePreviewImage(
              url: 'https://example.test/preview.png',
              imageProvider: MemoryImage(Uint8List.fromList(_transparentPng)),
            ),
          ),
        ),
      );

      // Nothing decoded yet, so the loading placeholder must be on screen.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Image decoding is real async work, which the fake clock does not drive.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Preview unavailable'), findsNothing);
    });
  });
}

/// A 1x1 transparent PNG.
const _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
];
