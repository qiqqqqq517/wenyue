import 'package:flutter/material.dart';

import 'di/app_container.dart';
import 'ui/library/library_page.dart';
import 'ui/settings/settings_view_model.dart';
import 'ui/theme.dart';

/// 应用根：主题跟随设置（浅色/深色/跟随系统）。
class WenyueApp extends StatefulWidget {
  const WenyueApp({super.key, required this.container});

  final AppContainer container;

  @override
  State<WenyueApp> createState() => _WenyueAppState();
}

class _WenyueAppState extends State<WenyueApp> {
  late final SettingsViewModel _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsViewModel.instance(widget.container);
    _settings.ensureLoaded();
    _settings.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _settings.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = switch (_settings.snapshot.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: '文阅',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: LibraryPage(container: widget.container),
    );
  }
}
