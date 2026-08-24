import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/constants/squi.dart';

void main() {
  test('every Squi pose has all three asset densities', () {
    for (final pose in SquiPose.values) {
      expect(File(pose.asset).existsSync(), isTrue, reason: pose.asset);
      final filename = pose.asset.split('/').last;
      for (final density in ['2.0x', '3.0x']) {
        final path = 'assets/images/squi/$density/$filename';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('pubspec declares the nested Squi asset directory', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/squi/'),
    );
  });
}
