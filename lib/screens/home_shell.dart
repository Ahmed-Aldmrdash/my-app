import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'schedule_screen.dart';
import 'study_screen.dart';
import 'subjects_screen.dart';
import 'tasks_hub_screen.dart';

/// The bottom-navigation shell holding the five main sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _tasksTab = ValueNotifier<int>(0);
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = NotificationService.instance;
    _taps = notifications.taps.stream.listen(_openPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch = notifications.launchPayload;
      if (launch != null) {
        notifications.launchPayload = null;
        _openPayload(launch);
      }
      await _askPermissionOnce();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    _tasksTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Daily summaries are computed ahead of time; refresh them whenever the
    // app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.scheduleSoon(context.read<AppStore>());
    }
  }

  Future<void> _askPermissionOnce() async {
    final store = context.read<AppStore>();
    if (store.settings.askedPermissions) return;
    await NotificationService.instance.requestPermission();
    await store.updateSettings(store.settings.copyWith(askedPermissions: true));
  }

  /// Payloads look like "tab:3:1" (tab 3, sub-tab 1).
  void _openPayload(String payload) {
    final parts = payload.split(':');
    if (parts.length < 2 || parts.first != 'tab') return;
    final tab = int.tryParse(parts[1]);
    final sub = parts.length > 2 ? int.tryParse(parts[2]) : null;
    if (tab == null) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _navigate(tab, sub);
  }

  void _navigate(int tab, [int? subTab]) {
    setState(() => _index = tab.clamp(0, 4));
    if (subTab != null) _tasksTab.value = subTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onNavigate: _navigate),
          const ScheduleScreen(),
          const StudyScreen(),
          TasksHubScreen(requestedTab: _tasksTab),
          const SubjectsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المذاكرة',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'المهام',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'المواد',
          ),
        ],
      ),
    );
  }
}
