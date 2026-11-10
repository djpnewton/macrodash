import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/theme.dart';

void main() {
  test('both themes provide the app colours', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.extension<AppColors>();
      expect(colors, isNotNull, reason: 'AppColors is required by appColors');
      expect(colors!.gain, isNot(colors.loss));
    }
  });

  test('app colours interpolate between themes', () {
    final light = AppTheme.light().extension<AppColors>()!;
    final dark = AppTheme.dark().extension<AppColors>()!;

    expect(light.lerp(dark, 0).gain, light.gain);
    expect(light.lerp(dark, 1).loss, dark.loss);
    expect(light.lerp(dark, 0.5).gain, isNot(light.gain));
  });

  test('copyWith replaces a single colour', () {
    final colors = AppTheme.light().extension<AppColors>()!;

    final updated = colors.copyWith(gain: const Color(0xFF123456));

    expect(updated.gain, const Color(0xFF123456));
    expect(updated.loss, colors.loss);
  });
}
