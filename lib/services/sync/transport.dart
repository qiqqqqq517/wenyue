import 'dart:typed_data';

/// 同步传输端口（领域侧抽象）。
///
/// 引擎只依赖此接口；WebDAV 仅为其中一个适配器，
/// 后续可替换为其他存储（如 S3、SMB）而不改动同步逻辑。
abstract interface class SyncTransport {
  /// 连通性检查。
  Future<void> ping();

  /// 读取文件；不存在返回 null（而非抛错）。
  Future<Uint8List?> read(String path);

  /// 写入文件（覆盖）。
  Future<void> write(String path, List<int> bytes);

  /// 递归建目录。
  Future<void> mkdirAll(String path);
}

/// 同步过程异常（保留 cause 展示给用户）。
class SyncException implements Exception {
  final String message;
  final Object? cause;

  SyncException(this.message, [this.cause]);

  @override
  String toString() =>
      cause == null ? message : '$message (${_brief(cause!)})';

  static String _brief(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}
