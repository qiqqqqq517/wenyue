import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenyue/data/impl/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsStore 书库视图', () {
    test('默认网格视图', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      expect(store.load().libraryView, 'grid');
    });

    test('切换列表视图并持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      final after = await store.setLibraryView('list');
      expect(after.libraryView, 'list');
      // 重新 load 仍为列表（持久化生效）
      expect(store.load().libraryView, 'list');

      await store.setLibraryView('grid');
      expect(store.load().libraryView, 'grid');
    });

    test('主题与视图互不影响', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      await store.setThemeMode('dark');
      await store.setLibraryView('list');
      final s = store.load();
      expect(s.themeMode, 'dark');
      expect(s.libraryView, 'list');
    });
  });

  group('SettingsStore 阅读字体', () {
    test('默认空字符串（系统默认字体）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      expect(store.load().readerFontFamily, '');
    });

    test('设置字体并持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      await store.setReaderFontFamily('微软雅黑');
      expect(store.load().readerFontFamily, '微软雅黑');

      await store.setReaderFontFamily('');
      expect(store.load().readerFontFamily, '');
    });
  });

  group('SettingsStore 书库排序偏好', () {
    test('默认 recent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      expect(store.loadLibrarySort(), 'recent');
    });

    test('保存后可读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      await store.saveLibrarySort('title');
      expect(store.loadLibrarySort(), 'title');

      await store.saveLibrarySort('progress');
      expect(store.loadLibrarySort(), 'progress');
    });
  });

  group('SettingsStore 搜索历史', () {
    test('默认空历史', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      expect(await store.loadSearchHistory(), isEmpty);
    });

    test('保存后可读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      await store.saveSearchHistory(['进程', '方法', '队列']);
      expect(await store.loadSearchHistory(), ['进程', '方法', '队列']);
    });

    test('去重（保序）与剔除空白项', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      await store.saveSearchHistory(['a', 'b', 'c']);
      final next = await store.saveSearchHistory(['b', 'd', ' a ', '']);
      // 'b' 提前（传入顺序），' a ' 去空格后与历史无重（历史里是 'a' 但本次
      // 传入序列自身去重按原值），空串剔除；结果 = 传入去重 + 历史补位
      expect(next.first, 'b');
      expect(next.contains('a'), isTrue);
      expect(next.contains('d'), isTrue);
      expect(next.contains(''), isFalse);
    });

    test('超过 10 条截断（保留最新）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);

      final input = List.generate(15, (i) => '词$i');
      final next = await store.saveSearchHistory(input);
      expect(next.length, 10);
      expect(next.first, '词0');
      expect(next.last, '词9');
    });
  });
}
