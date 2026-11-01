/// WCAG 2.x 对比度计算（纯函数）。
///
/// 用于主题回归护栏：防止未来改种子色/覆盖颜色时把深色模式的
/// 文本/背景对比度降到不可读（AA 正文 ≥ 4.5，大字 ≥ 3.0）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 相对亮度（WCAG 定义，sRGB 线性化）。
double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// 对比度（(L1+0.05)/(L2+0.05)，结果 ≥ 1）。
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
