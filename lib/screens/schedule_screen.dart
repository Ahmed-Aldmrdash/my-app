import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'session_form.dart';

/// The weekly timetable, one tab per day starting Saturday.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: weekOrder.length,
    vsync: this,
    initialIndex: weekOrder.indexOf(DateTime.now().weekday),
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = DateTime.now().weekday;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final d in weekOrder)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d == today
                          ? '${weekdayNames[d]!} (النهارده)'
                          : weekdayNames[d]!,
                    ),
                    if (store.sessionsOn(d).isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Badge(
                        label: Text('${store.sessionsOn(d).length}'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        textColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [for (final d in weekOrder) _DayView(weekday: d)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule-fab',
        onPressed: () => pushPage(
          context,
          SessionForm(initialWeekday: weekOrder[_tabs.index]),
        ),
        icon: const Icon(Icons.add),
        label: const Text('ميعاد جديد'),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sessions = store.sessionsOn(weekday);
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.free_breakfast_outlined,
        title: 'مفيش حاجة يوم ${weekdayNames[weekday]}',
        message: store.subjects.isEmpty
            ? 'ضيف موادك الأول، وبعدين ضيف مواعيد المحاضرات والسكاشن هنا'
            : 'دوس على "ميعاد جديد" عشان تضيف محاضرة أو سكشن',
      );
    }
    return NowBuilder(
      builder: (context, now) {
        final nowMinute = now.hour * 60 + now.minute;
        final isToday = now.weekday == weekday;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            for (final s in sessions)
              SessionTile(
                session: s,
                highlight:
                    isToday &&
                    s.startMinute <= nowMinute &&
                    nowMinute < s.endMinute,
              ),
          ],
        );
      },
    );
  }
}
