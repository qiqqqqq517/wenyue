import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/core/app_info.dart';

/// 版本号单一来源护栏。
///
/// 历史问题：v1.10.0 之后每轮发版只改 `pubspec.yaml`，`kAppVersion` 长期停在
/// 1.9.0，设置页因此一直显示「v1.9.0」。此测试直接对拍两个文件，防止再漂移。
void main() {
  test('kAppVersion 与 pubspec.yaml 的 version 前缀一致', () {
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: '测试须在仓库根目录运行');

    final line = pubspec
        .readAsLinesSync()
        .map((l) => l.trim())
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim();
    final prefix = version.split('+').first;

    expect(
      kAppVersion,
      prefix,
      reason: 'lib/core/app_info.dart 的 kAppVersion 落后于 pubspec.yaml '
          '（pubspec=$version, kAppVersion=$kAppVersion），发版时两处必须同步',
    );
  });

  test('kAppVersion 为合法的三段式版本号', () {
    expect(
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(kAppVersion),
      isTrue,
      reason: 'kAppVersion=$kAppVersion 不是 X.Y.Z 形式',
    );
  });

  test('应用名为「文阅」', () {
    expect(kAppName, '文阅');
  });
}
