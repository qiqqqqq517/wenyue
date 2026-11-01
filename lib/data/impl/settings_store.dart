import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置快照（值不可变；跨平台持久化由本类完成）。
class SettingsSnapshot {
  final String themeMode; // system | light | dark
  final double readerFontSize;
  final double readerLineHeight;
  final String readerFontFamily; // '' = 默认字体
  final String libraryView; // grid | list

  const SettingsSnapshot({
    this.themeMode = 'system',
    this.readerFontSize = 16.0,
    this.readerLineHeight = 1.7,
    this.readerFontFamily = '',
    this.libraryView = 'grid',
  });

  SettingsSnapshot copyWith({
    String? themeMode,
    double? readerFontSize,
    double? readerLineHeight,
    String? readerFontFamily,
    String? libraryView,
  }) =>
      SettingsSnapshot(
        themeMode: themeMode ?? this.themeMode,
        readerFontSize: readerFontSize ?? this.readerFontSize,
        readerLineHeight: readerLineHeight ?? this.readerLineHeight,
        readerFontFamily: readerFontFamily ?? this.readerFontFamily,
        libraryView: libraryView ?? this.libraryView,
      );
}

/// WebDAV 配置（不含密码；密码存系统安全存储）。
class WebDavConfig {
  final String serverUrl;
  final String username;
  final String basePath; // 远端根目录，如 /wenyue-sync

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.basePath,
  });

  bool get isComplete => serverUrl.isNotEmpty && basePath.isNotEmpty;
}

/// 设置存储：非敏感项 SharedPreferences，凭据走系统安全存储。
/// 按安全约束：密码不落盘于明文配置，也不写进源码/示例。
class SettingsStore {
  SettingsStore(this._prefs, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kTheme = 'theme.mode';
  static const _kFontSize = 'reader.fontSize';
  static const _kLineHeight = 'reader.lineHeight';
  static const _kFontFamily = 'reader.fontFamily';
  static const _kLibraryView = 'library.view';
  static const _kDavUrl = 'webdav.url';
  static const _kDavUser = 'webdav.user';
  static const _kDavBase = 'webdav.basePath';
  static const _kDavPassword = 'webdav.password';
  static const _kDavAutoBackup = 'webdav.autoBackup';

  SettingsSnapshot load() => SettingsSnapshot(
        themeMode: _prefs.getString(_kTheme) ?? 'system',
        readerFontSize: _prefs.getDouble(_kFontSize) ?? 16.0,
        readerLineHeight: _prefs.getDouble(_kLineHeight) ?? 1.7,
        readerFontFamily: _prefs.getString(_kFontFamily) ?? '',
        libraryView: _prefs.getString(_kLibraryView) ?? 'grid',
      );

  Future<SettingsSnapshot> setThemeMode(String v) async {
    await _prefs.setString(_kTheme, v);
    return load();
  }

  Future<SettingsSnapshot> setReaderFontSize(double v) async {
    await _prefs.setDouble(_kFontSize, v);
    return load();
  }

  Future<SettingsSnapshot> setReaderLineHeight(double v) async {
    await _prefs.setDouble(_kLineHeight, v);
    return load();
  }

  Future<SettingsSnapshot> setReaderFontFamily(String v) async {
    await _prefs.setString(_kFontFamily, v);
    return load();
  }

  /// 书库视图模式（grid / list）。
  Future<SettingsSnapshot> setLibraryView(String v) async {
    await _prefs.setString(_kLibraryView, v);
    return load();
  }

  /// 搜索历史（最近优先，去重，最多 10 条；跨文档共享）。
  static const _kSearchHistory = 'reader.searchHistory';
  static const _kSearchHistoryMax = 10;

  Future<List<String>> loadSearchHistory() async =>
      _prefs.getStringList(_kSearchHistory) ?? const [];

  Future<List<String>> saveSearchHistory(List<String> history) async {
    // 去重（保持顺序）并截断到上限
    final seen = <String>{};
    final next = <String>[];
    for (final h in history) {
      final t = h.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      next.add(t);
      if (next.length >= _kSearchHistoryMax) break;
    }
    await _prefs.setStringList(_kSearchHistory, next);
    return next;
  }

  Future<WebDavConfig> loadWebDavConfig() async => WebDavConfig(
        serverUrl: _prefs.getString(_kDavUrl) ?? '',
        username: _prefs.getString(_kDavUser) ?? '',
        basePath: _prefs.getString(_kDavBase) ?? '/wenyue-sync',
      ).normalize();

  Future<void> saveWebDavConfig(WebDavConfig c) async {
    await _prefs.setString(_kDavUrl, c.serverUrl);
    await _prefs.setString(_kDavUser, c.username);
    await _prefs.setString(_kDavBase, c.basePath);
  }

  Future<bool> get autoBackupBeforeSync =>
      Future.value(_prefs.getBool(_kDavAutoBackup) ?? true);

  Future<void> setAutoBackupBeforeSync(bool v) =>
      _prefs.setBool(_kDavAutoBackup, v);

  Future<String?> loadPassword() => _secure.read(key: _kDavPassword);

  Future<void> savePassword(String? value) async {
    if (value == null || value.isEmpty) {
      await _secure.delete(key: _kDavPassword);
    } else {
      await _secure.write(key: _kDavPassword, value: value);
    }
  }
}

/// WebDavConfig 规范化（公共扩展，供设置页直接调用）。
extension WebDavConfigX on WebDavConfig {
  /// 校验并规范化：仅允许 http/https 与非空主机，规范化 basePath。
  ///
  /// 安全说明：这是用户自配端点的本地客户端（不是代取外部 URL 的服务端），
  /// 局域网 NAS（私有网段）是主要使用场景，因此不拦截私有地址；
  /// 仅强制 scheme 与主机名合法性，凭据存放于系统安全存储。
  WebDavConfig normalize() {
    final url = serverUrl.trim();
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }
    final validUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!validUrl) {
      return WebDavConfig(serverUrl: '', username: username, basePath: basePath);
    }
    var base = basePath.trim();
    if (!base.startsWith('/')) base = '/$base';
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return WebDavConfig(serverUrl: url, username: username, basePath: base);
  }
}
