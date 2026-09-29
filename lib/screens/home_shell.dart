import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/reminder_planner.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
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
      context.read<SyncService>().onResume();
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

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'الجدول'),
    (Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'المذاكرة'),
    (Icons.checklist_rounded, Icons.fact_check_rounded, 'المهام'),
    (Icons.school_outlined, Icons.school_rounded, 'المواد'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _index,
      children: [
        DashboardScreen(onNavigate: _navigate),
        const ScheduleScreen(),
        const StudyScreen(),
        TasksHubScreen(requestedTab: _tasksTab),
        const SubjectsScreen(),
      ],
    );
    final width = MediaQuery.sizeOf(context).width;

    // Computers and tablets: a side rail and a centred column.
    if (width >= wideLayoutWidth) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _navigate,
              extended: width >= 1150,
              minExtendedWidth: 210,
              backgroundColor: theme.colorScheme.surfaceContainerLowest,
              indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
              labelType: width >= 1150
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconBadge(
                      Icons.auto_stories_rounded,
                      color: AppColors.primary,
                      filled: true,
                    ),
                    if (width >= 1150) ...[
                      const SizedBox(width: 10),
                      Text(
                        'منظم دراستي',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2, color: theme.colorScheme.primary),
                    label: Text(d.$3),
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: pages,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _navigate,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
