import 'package:dating_app/presentation/explore/widgets/explore_marker_images.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

/// How big a marker actually comes out on screen.
///
/// MapLibre draws an icon at `bitmapPixels ÷ image.pixelRatio × icon-size`,
/// and the plugin declares a different `pixelRatio` per platform — 1 on the
/// web, the device's own on Android and iOS. A single fixed `icon-size` is
/// therefore right on exactly one of them, and the flat `1 / rasterScale` this
/// replaces was right on the web: on a 3× phone every face came out a third
/// of the size it was drawn at.
///
/// These assert the on-screen size the layer will produce, rather than the
/// factor itself — the factor is the workaround, the size is the promise.
void main() {
  /// Logical size a marker bitmap ends up occupying, for a given screen.
  double displayedSize({
    required double bitmapPixels,
    required double devicePixelRatio,
  }) {
    // What the plugin tells MapLibre the image's ratio is.
    final declared = kIsWeb ? 1.0 : devicePixelRatio;
    return bitmapPixels /
        declared *
        ExploreMarkerImages.iconSizeFor(devicePixelRatio);
  }

  // The unselected disc, rasterised at `rasterScale`.
  const disc = 54.0;
  const bitmap = disc * ExploreMarkerImages.rasterScale;

  test('draws at life size on a 1× screen', () {
    expect(
      displayedSize(bitmapPixels: bitmap, devicePixelRatio: 1),
      closeTo(disc, 0.001),
    );
  });

  test('draws at the same size on a 3× phone', () {
    // The regression: this used to come out at 18, and the faces on the map
    // were a third of the size of the same build on the web.
    expect(
      displayedSize(bitmapPixels: bitmap, devicePixelRatio: 3),
      closeTo(disc, 0.001),
    );
  });

  test('draws at the same size across every ratio in the wild', () {
    for (final ratio in [1.0, 1.5, 2.0, 2.625, 2.75, 3.0, 3.5, 4.0]) {
      expect(
        displayedSize(bitmapPixels: bitmap, devicePixelRatio: ratio),
        closeTo(disc, 0.001),
        reason: 'a $ratio× screen should show the same $disc dp marker',
      );
    }
  });

  test('scales the selected marker up, not down', () {
    // Selection is a separate raster (62 vs 54) drawn on its own layer; the
    // size rule has to leave that difference intact rather than flatten it.
    const selected = 62.0;
    expect(
      displayedSize(
        bitmapPixels: selected * ExploreMarkerImages.rasterScale,
        devicePixelRatio: 3,
      ),
      greaterThan(displayedSize(bitmapPixels: bitmap, devicePixelRatio: 3)),
    );
  });

  test('is a pure function of the ratio', () {
    // It is read on every layer push, including animation ticks.
    expect(
      ExploreMarkerImages.iconSizeFor(2.75),
      ExploreMarkerImages.iconSizeFor(2.75),
    );
  });
}
