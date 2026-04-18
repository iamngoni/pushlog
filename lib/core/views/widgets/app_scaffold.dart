//
//  pushlog
//  app_scaffold.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/history/views/pages/history_page.dart';
import 'package:pushlog/settings/views/pages/settings_page.dart';
import 'package:pushlog/today/views/pages/today_page.dart';

enum PushlogTab { today, history, settings }

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  PushlogTab selectedTab = PushlogTab.today;

  void onTabChanged(PushlogTab tab) {
    setState(() => selectedTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: buildBody(),
    );
  }

  Widget buildBody() {
    switch (selectedTab) {
      case PushlogTab.today:
        return TodayPage(
          selectedTab: selectedTab,
          onTabChanged: onTabChanged,
        );
      case PushlogTab.history:
        return HistoryPage(
          selectedTab: selectedTab,
          onTabChanged: onTabChanged,
        );
      case PushlogTab.settings:
        return SettingsPage(
          selectedTab: selectedTab,
          onTabChanged: onTabChanged,
        );
    }
  }
}
