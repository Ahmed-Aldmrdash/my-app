import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/reminder_planner.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'focus_screen.dart';
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
  Timer? _focusCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = NotificationService.instance;
    _taps = notifications.taps.stream.listen(_openPayload);
    // Finish a focus session that ended while the app was in the background
    // or on another screen.
    _focusCheck = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _completeFocus(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _completeFocus();
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
    _focusCheck?.cancel();
    _tasksTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _completeFocus();
      // Daily summaries are computed ahead of time; refresh them whenever
      // the app comes back to the foreground.
      NotificationService.instance.scheduleSoon(context.read<AppStore>());
    }
  }

  Future<void> _completeFocus() async {
    if (!mounted || FocusScreen.isOpen) return;
    final store = context.read<AppStore>();
    final focus = store.focus;
    final finished = await store.completeFocusIfDue();
    if (!mounted || finished == null || focus == null) return;
    showSnack(
      context,
      finished == FocusPhase.focus
          ? '🎉 خلصت جلسة ${studyTimeText((focus.plannedSeconds / 60).round())} واتسجلت'
          : '⏰ البريك خلص — يلا نكمل',
    );
  }

  Future<void> _askPermissionOnce() async {
    final store = context.read<AppStore>();
    if (store.settings.askedPermissions) return;
    await NotificationService.instance.requestPermission();
    await store.updateSettings(store.settings.copyWith(askedPermissions: true));
  }

  /// Payloads look like "tab:3:1" (tab 3, sub-tab 1) or "focus".
  void _openPayload(String payload) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (payload == ReminderTarget.focus) {
      pushPage(context, const FocusScreen());
      return;
    }
    final parts = payload.split(':');
    if (parts.length < 2 || parts.first != 'tab') return;
    final tab = int.tryParse(parts[1]);
    final sub = parts.length > 2 ? int.tryParse(parts[2]) : null;
    if (tab == null) return;
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
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'المذاكرة',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'المهام',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'المواد',
          ),
        ],
      ),
    );
  }
}
