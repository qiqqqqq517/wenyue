/// 代码块轻量语法高亮：零第三方依赖的纯 Dart 词法着色。
///
/// 只做「关键字 / 字符串 / 注释 / 数字」四类着色，覆盖常见语言，
/// 未知语言退化为通用扫描（字符串、注释、数字），不影响渲染。
library;

/// 代码 token 类型（仅用于着色）。
enum CodeTokenKind { plain, keyword, string, comment, number }

/// 代码片段：`[start, end)` 字符区间。
class CodeToken {
  final int start;
  final int end;
  final CodeTokenKind kind;

  const CodeToken(this.start, this.end, this.kind);

  @override
  String toString() => 'CodeToken($start,$end,$kind)';
}

/// 语言关键字表（别名在 [_normalize] 中归一）。
const Map<String, Set<String>> kCodeKeywords = {
  'dart': {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'get', 'hide', 'if',
    'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
    'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
  },
  'python': {
    'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue',
    'def', 'del', 'elif', 'else', 'except', 'False', 'finally', 'for', 'from',
    'global', 'if', 'import', 'in', 'is', 'lambda', 'None', 'nonlocal', 'not',
    'or', 'pass', 'raise', 'return', 'True', 'try', 'while', 'with', 'yield',
  },
  'javascript': {
    'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'delete', 'do', 'else', 'export', 'extends', 'false', 'finally',
    'for', 'from', 'function', 'get', 'if', 'import', 'in', 'instanceof',
    'let', 'new', 'null', 'of', 'return', 'set', 'static', 'super', 'switch',
    'this', 'throw', 'true', 'try', 'typeof', 'undefined', 'var', 'while',
    'yield',
  },
  'java': {
    'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char',
    'class', 'const', 'continue', 'default', 'do', 'double', 'else', 'enum',
    'extends', 'final', 'finally', 'float', 'for', 'if', 'implements',
    'import', 'instanceof', 'int', 'interface', 'long', 'new', 'null',
    'package', 'private', 'protected', 'public', 'return', 'short', 'static',
    'strictfp', 'super', 'switch', 'synchronized', 'this', 'throw', 'throws',
    'transient', 'true', 'false', 'try', 'void', 'volatile', 'while',
  },
  'kotlin': {
    'as', 'break', 'class', 'continue', 'data', 'do', 'else', 'false', 'for',
    'fun', 'if', 'in', 'interface', 'is', 'null', 'object', 'override',
    'package', 'private', 'protected', 'public', 'return', 'sealed', 'super',
    'this', 'throw', 'true', 'try', 'typealias', 'val', 'var', 'when', 'while',
    'by', 'catch', 'constructor', 'delegate', 'dynamic', 'field', 'file',
    'finally', 'get', 'import', 'init', 'param', 'property', 'receiver', 'set',
    'setparam', 'where', 'actual', 'abstract', 'annotation', 'companion',
    'const', 'crossinline', 'expect', 'external', 'final', 'infix', 'inline',
    'inner', 'internal', 'lateinit', 'noinline', 'open', 'operator', 'out',
    'reified', 'suspend', 'tailrec', 'vararg', 'enum',
  },
  'c': {
    'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
    'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if', 'int',
    'long', 'register', 'return', 'short', 'signed', 'sizeof', 'static',
    'struct', 'switch', 'typedef', 'union', 'unsigned', 'void', 'volatile',
    'while', 'NULL', 'true', 'false', 'bool',
  },
  'go': {
    'break', 'case', 'chan', 'const', 'continue', 'default', 'defer', 'else',
    'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import', 'interface',
    'map', 'package', 'range', 'return', 'select', 'struct', 'switch', 'type',
    'var', 'nil', 'true', 'false',
  },
  'rust': {
    'as', 'async', 'await', 'break', 'const', 'continue', 'crate', 'dyn',
    'else', 'enum', 'extern', 'false', 'fn', 'for', 'if', 'impl', 'in', 'let',
    'loop', 'match', 'mod', 'move', 'mut', 'pub', 'ref', 'return', 'self',
    'Self', 'static', 'struct', 'super', 'trait', 'true', 'type', 'unsafe',
    'use', 'where', 'while', 'yield',
  },
  'sql': {
    'select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set',
    'delete', 'create', 'table', 'drop', 'alter', 'join', 'left', 'right',
    'inner', 'outer', 'on', 'group', 'by', 'order', 'having', 'limit',
    'offset', 'as', 'and', 'or', 'not', 'null', 'is', 'in', 'like', 'between',
    'union', 'all', 'distinct', 'case', 'when', 'then', 'else', 'end', 'count',
    'sum', 'avg', 'min', 'max', 'primary', 'key', 'foreign', 'references',
    'index', 'view', 'true', 'false',
  },
  'bash': {
    'if', 'then', 'else', 'elif', 'fi', 'for', 'in', 'do', 'done', 'while',
    'until', 'case', 'esac', 'function', 'return', 'echo', 'export', 'local',
    'readonly', 'exit', 'set', 'unset', 'shift', 'true', 'false',
  },
  'yaml': {'true', 'false', 'null', 'yes', 'no'},
  'json': {'true', 'false', 'null'},
};

String _normalize(String? language) {
  final l = (language ?? '').trim().toLowerCase();
  return switch (l) {
    'js' || 'mjs' || 'cjs' || 'javascript' => 'javascript',
    'ts' || 'typescript' => 'javascript',
    'py' || 'python3' => 'python',
    'sh' || 'shell' || 'zsh' || 'console' => 'bash',
    'yml' => 'yaml',
    'c++' || 'cxx' || 'cpp' => 'c',
    'kt' || 'kts' => 'kotlin',
    'rs' => 'rust',
    'golang' => 'go',
    'postgres' || 'postgresql' || 'mysql' || 'sqlite' => 'sql',
    _ => l,
  };
}

bool _isHashCommentLang(String lang) =>
    lang == 'python' || lang == 'bash' || lang == 'yaml';

bool _isSqlLike(String lang) => lang == 'sql';

bool _isCFamily(String lang) => const {
      'dart', 'javascript', 'java', 'kotlin', 'c', 'go', 'rust', 'json',
    }.contains(lang);

/// 词法扫描：返回按位置升序、互不重叠的 token 列表。
List<CodeToken> tokenizeCode(String code, {String? language}) {
  final lang = _normalize(language);
  final keywords = kCodeKeywords[lang] ?? const <String>{};
  final caseInsensitive = lang == 'sql';
  final out = <CodeToken>[];
  final n = code.length;
  var i = 0;

  bool startsWithAt(String s) =>
      i + s.length <= n && code.startsWith(s, i);

  while (i < n) {
    final c = code[i];

    // 注释
    if (_isCFamily(lang) && startsWithAt('//')) {
      final end = _lineEnd(code, i);
      out.add(CodeToken(i, end, CodeTokenKind.comment));
      i = end;
      continue;
    }
    if (_isHashCommentLang(lang) && c == '#') {
      final end = _lineEnd(code, i);
      out.add(CodeToken(i, end, CodeTokenKind.comment));
      i = end;
      continue;
    }
    if (_isSqlLike(lang) && startsWithAt('--')) {
      final end = _lineEnd(code, i);
      out.add(CodeToken(i, end, CodeTokenKind.comment));
      i = end;
      continue;
    }
    // 未知语言也识别通用注释，避免整段无着色
    if (keywords.isEmpty && !_isCFamily(lang) && !_isHashCommentLang(lang)) {
      if (startsWithAt('//') || startsWithAt('#')) {
        final end = _lineEnd(code, i);
        out.add(CodeToken(i, end, CodeTokenKind.comment));
        i = end;
        continue;
      }
    }
    if ((_isCFamily(lang) || keywords.isEmpty) && startsWithAt('/*')) {
      final close = code.indexOf('*/', i + 2);
      final end = close < 0 ? n : close + 2;
      out.add(CodeToken(i, end, CodeTokenKind.comment));
      i = end;
      continue;
    }

    // 字符串（单/双/反引号，支持反斜杠转义）
    if (c == "'" || c == '"' || c == '`') {
      final end = _stringEnd(code, i, c);
      out.add(CodeToken(i, end, CodeTokenKind.string));
      i = end;
      continue;
    }

    // 数字
    if (_isDigit(c)) {
      var j = i + 1;
      if (c == '0' && j < n && (code[j] == 'x' || code[j] == 'X')) {
        j++;
        while (j < n && _isHex(code[j])) {
          j++;
        }
      } else {
        while (j < n && (_isDigit(code[j]) || code[j] == '.' || code[j] == '_')) {
          j++;
        }
        // 科学计数法
        if (j < n && (code[j] == 'e' || code[j] == 'E')) {
          var k = j + 1;
          if (k < n && (code[k] == '+' || code[k] == '-')) k++;
          if (k < n && _isDigit(code[k])) {
            while (k < n && _isDigit(code[k])) {
              k++;
            }
            j = k;
          }
        }
      }
      out.add(CodeToken(i, j, CodeTokenKind.number));
      i = j;
      continue;
    }

    // 标识符 / 关键字
    if (_isIdentStart(c)) {
      var j = i + 1;
      while (j < n && _isIdentPart(code[j])) {
        j++;
      }
      final word = code.substring(i, j);
      final isKeyword =
          keywords.contains(caseInsensitive ? word.toLowerCase() : word);
      if (isKeyword) {
        out.add(CodeToken(i, j, CodeTokenKind.keyword));
      }
      i = j;
      continue;
    }

    i++;
  }
  return out;
}

bool _isDigit(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x30 && u <= 0x39;
}

bool _isHex(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x30 && u <= 0x39) ||
      (u >= 0x41 && u <= 0x46) ||
      (u >= 0x61 && u <= 0x66);
}

bool _isIdentStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x41 && u <= 0x5A) ||
      (u >= 0x61 && u <= 0x7A) ||
      c == '_' ||
      c == r'$';
}

bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);

int _lineEnd(String code, int from) {
  final nl = code.indexOf('\n', from);
  return nl < 0 ? code.length : nl;
}

int _stringEnd(String code, int start, String quote) {
  var i = start + 1;
  while (i < code.length) {
    final c = code[i];
    if (c == r'\' && i + 1 < code.length) {
      i += 2;
      continue;
    }
    if (c == quote) return i + 1;
    i++;
  }
  return code.length;
}
