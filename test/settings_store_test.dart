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
}
