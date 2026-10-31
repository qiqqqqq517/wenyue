import 'package:flutter/foundation.dart';

import '../../data/impl/settings_store.dart';
import '../../di/app_container.dart';

/// 设置视图模型：主题与阅读排版默认值。
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel._(this._store);

  static SettingsViewModel? _instance;

  factory SettingsViewModel.instance(AppContainer container) {
    return _instance ??= SettingsViewModel._(container.settings);
  }

  final SettingsStore _store;

  SettingsSnapshot _snapshot = const SettingsSnapshot();
  SettingsSnapshot get snapshot => _snapshot;

  Future<void> ensureLoaded() async {
    _snapshot = _store.load();
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _snapshot = await _store.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setReaderFontSize(double v) async {
    _snapshot = await _store.setReaderFontSize(v);
    notifyListeners();
  }

  Future<void> setReaderLineHeight(double v) async {
    _snapshot = await _store.setReaderLineHeight(v);
    notifyListeners();
  }

  Future<void> setReaderFontFamily(String v) async {
    _snapshot = await _store.setReaderFontFamily(v);
    notifyListeners();
  }
}
