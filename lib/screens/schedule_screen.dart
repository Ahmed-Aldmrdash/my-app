import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'session_form.dart';

/// The weekly timetable, one page per day starting Saturday.
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
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final today = DateTime.now().weekday;
    final lectures = store.sessions
        .where((s) => s.type == SessionType.lecture)
        .length;
    final others = store.sessions.length - lectures;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (store.sessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: Text(
                    'في الأسبوع: $lectures محاضرات و$others سكاشن ولابات',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicator: const BoxDecoration(),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                tabs: [
                  for (var i = 0; i < weekOrder.length; i++)
                    _DayPill(
                      weekday: weekOrder[i],
                      count: store.sessionsOn(weekOrder[i]).length,
                      selected: _tabs.index == i,
                      isToday: weekOrder[i] == today,
                    ),
                ],
              ),
            ],
          ),
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('ميعاد جديد'),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.weekday,
    required this.count,
    required this.selected,
    required this.isToday,
  });

  final int weekday;
  final int count;
  final bool selected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 62,
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selected ? primary : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: isToday && !selected
            ? Border.all(color: primary, width: 1.5)
            : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              weekdayShortNames[weekday]!,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count.clamp(0, 4); i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? fg.withValues(alpha: 0.9)
                        : primary.withValues(alpha: 0.7),
                  ),
                ),
              if (count == 0)
                Text(
                  '—',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    height: 1,
                  ),
                ),
            ],
          ),
          if (isToday)
            FittedBox(
              child: Text(
                'النهارده',
                style: TextStyle(
                  color: selected ? fg : primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
        ],
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
        icon: Icons.free_breakfast_rounded,
        title: 'مفيش حاجة يوم ${weekdayNames[weekday]}',
        message: store.subjects.isEmpty
            ? 'ضيف موادك الأول، وبعدين ضيف مواعيد المحاضرات والسكاشن هنا'
            : 'يوم راحة 😎 — أو دوس "ميعاد جديد" تضيف محاضرة أو سكشن',
      );
    }
    return NowBuilder(
      builder: (context, now) {
        final nowMinute = now.hour * 60 + now.minute;
        final isToday = now.weekday == weekday;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            for (final s in sessions)
              SessionTile(
                session: s,
                highlight:
                    isToday &&
                    s.startMinute <= nowMinute &&
                    nowMinute < s.endMinute,
                attendanceDay: isToday && s.startMinute <= nowMinute
                    ? now
                    : null,
              ),
          ],
        );
      },
    );
  }
}
