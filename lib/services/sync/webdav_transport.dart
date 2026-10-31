import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart' as webdav;

import 'transport.dart';

/// WebDAV 适配器：实现 [SyncTransport]。
///
/// 远端路径统一以配置的 basePath 为根；凭据由调用方从系统安全存储读出。
class WebDavTransport implements SyncTransport {
  WebDavTransport({
    required String serverUrl,
    required String username,
    required String password,
    required this.basePath,
  }) {
    _client = webdav.newClient(
      serverUrl,
      user: username,
      password: password,
      debug: false,
    );
  }

  late final webdav.Client _client;

  /// 远端根目录（如 /wenyue-sync）。
  final String basePath;

  String _abs(String relative) {
    final rel = relative.startsWith('/') ? relative.substring(1) : relative;
    return basePath.isEmpty ? '/$rel' : '$basePath/$rel';
  }

  @override
  Future<void> ping() async {
    try {
      await _client.ping();
    } catch (e) {
      throw SyncException('无法连接 WebDAV 服务器', e);
    }
  }

  @override
  Future<void> mkdirAll(String path) async {
    try {
      await _client.mkdirAll(_abs(path));
    } catch (e) {
      throw SyncException('创建远端目录失败: $path', e);
    }
  }

  @override
  Future<Uint8List?> read(String path) async {
    try {
      final data = await _client.read(_abs(path));
      return Uint8List.fromList(data);
    } catch (e) {
      if (_isNotFound(e)) return null;
      throw SyncException('读取远端文件失败: $path', e);
    }
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    try {
      await _client.write(_abs(path), Uint8List.fromList(bytes));
    } catch (e) {
      throw SyncException('写入远端文件失败: $path', e);
    }
  }

  bool _isNotFound(Object e) {
    final s = e.toString();
    return s.contains('404') || s.contains('Not Found') || s.contains('NC_EFILENOTFOUND');
  }
}
