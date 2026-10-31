import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/readers/text/code_highlighter.dart';

void main() {
  group('tokenizeCode · Dart', () {
    test('关键字/字符串/注释/数字分类', () {
      const code = '''
// 注释行
final x = 42;
var name = "hello";
class Foo {}
''';
      final tokens = tokenizeCode(code, language: 'dart');
      final kinds = {for (final t in tokens) code.substring(t.start, t.end): t.kind};

      expect(kinds['// 注释行'], CodeTokenKind.comment);
      expect(kinds['final'], CodeTokenKind.keyword);
      expect(kinds['class'], CodeTokenKind.keyword);
      expect(kinds['42'], CodeTokenKind.number);
      expect(kinds['"hello"'], CodeTokenKind.string);
      // 标识符不着色
      expect(kinds.containsKey('name'), isFalse);
    });

    test('字符串内含 // 不误判为注释；转义引号正确', () {
      const code = r'''
var url = "http://x"; // real comment
var esc = "a\"b";
''';
      final tokens = tokenizeCode(code, language: 'dart');
      final commentTokens =
          tokens.where((t) => t.kind == CodeTokenKind.comment).toList();
      expect(commentTokens, hasLength(1));
      expect(code.substring(commentTokens.single.start, commentTokens.single.end),
          '// real comment');
      // "http://x" 整段是字符串
      final strTokens =
          tokens.where((t) => t.kind == CodeTokenKind.string).toList();
      expect(strTokens.map((t) => code.substring(t.start, t.end)),
          contains('"http://x"'));
      // 转义引号的字符串完整闭合
      expect(strTokens.map((t) => code.substring(t.start, t.end)),
          contains(r'"a\"b"'));
    });

    test('多行 /* */ 注释整体着色', () {
      const code = 'int a; /* span\nning */ int b;';
      final tokens = tokenizeCode(code, language: 'c');
      final c = tokens.singleWhere((t) => t.kind == CodeTokenKind.comment);
      expect(code.substring(c.start, c.end), '/* span\nning */');
    });
  });

  group('tokenizeCode · 其他语言', () {
    test('Python # 注释与 True/None 关键字', () {
      const code = '# 注释\nx = True\ny = None\n';
      final tokens = tokenizeCode(code, language: 'python');
      final kinds = {for (final t in tokens) code.substring(t.start, t.end): t.kind};
      expect(kinds['# 注释'], CodeTokenKind.comment);
      expect(kinds['True'], CodeTokenKind.keyword);
      expect(kinds['None'], CodeTokenKind.keyword);
    });

    test('SQL 大小写不敏感关键字与 -- 注释', () {
      const code = '-- note\nSELECT id FROM users;\nselect * from t;';
      final tokens = tokenizeCode(code, language: 'sql');
      final keywords =
          tokens.where((t) => t.kind == CodeTokenKind.keyword).toList();
      final words = keywords
          .map((t) => code.substring(t.start, t.end).toLowerCase())
          .toList();
      expect(words, containsAll(['select', 'from', 'select', 'from']));
      final comments = tokens.where((t) => t.kind == CodeTokenKind.comment);
      expect(comments, isNotEmpty);
    });

    test('十六进制与科学计数法数字', () {
      const code = 'var a = 0xFF; var b = 1.5e-3;';
      final tokens = tokenizeCode(code, language: 'dart');
      final nums = tokens.where((t) => t.kind == CodeTokenKind.number).toList();
      final values = nums.map((t) => code.substring(t.start, t.end)).toList();
      expect(values, containsAll(['0xFF', '1.5e-3']));
    });

    test('未知语言退化为通用扫描（字符串+注释+数字）', () {
      const code = 'x = 123 # note\ns = "abc"';
      final tokens = tokenizeCode(code, language: 'cobol');
      final kinds = {for (final t in tokens) code.substring(t.start, t.end): t.kind};
      expect(kinds['123'], CodeTokenKind.number);
      expect(kinds['# note'], CodeTokenKind.comment);
      expect(kinds['"abc"'], CodeTokenKind.string);
    });

    test('别名归一：ts 按 JavaScript、kt 按 Kotlin 着色', () {
      const ts = 'const x: number = 1;';
      expect(
        tokenizeCode(ts, language: 'ts')
            .any((t) => ts.substring(t.start, t.end) == 'const'),
        isTrue,
      );
      const kt = 'val x = fun(): Int { return 1 }';
      final ktTokens = tokenizeCode(kt, language: 'kt')
          .where((t) => t.kind == CodeTokenKind.keyword)
          .map((t) => kt.substring(t.start, t.end))
          .toList();
      expect(ktTokens, containsAll(['val', 'fun', 'return']));
    });

    test('token 区间互不重叠且升序', () {
      const code = '''
final list = [1, 2, 3]; // comment
String s = 'multi\nline? no';
''';
      final tokens = tokenizeCode(code, language: 'dart');
      for (var i = 1; i < tokens.length; i++) {
        expect(tokens[i].start, greaterThanOrEqualTo(tokens[i - 1].end));
      }
    });
  });
}
