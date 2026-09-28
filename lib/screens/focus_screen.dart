import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/quotes.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import 'stats_screen.dart';

/// Pomodoro-style focus timer: pick a subject, focus, take a break.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.subjectId, this.studyItemId});

  final String? subjectId;
  final String? studyItemId;

  /// True while the screen is on top, so other parts of the app leave the
  /// completion handling (and celebration) to it.
  static bool isOpen = false;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late String? _subjectId = widget.subjectId;
  late String? _studyItemId = widget.studyItemId;
  late int _minutes = context.read<AppStore>().settings.focusMinutes;
  Timer? _ticker;
  bool _handling = false;

  static const _presets = [15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    FocusScreen.isOpen = true;
    final running = context.read<AppStore>().focus;
    if (running != null) {
      _subjectId = running.subjectId;
      _studyItemId = running.studyItemId;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    FocusScreen.isOpen = false;
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || _handling) return;
    final store = context.read<AppStore>();
    final focus = store.focus;
    if (focus != null && focus.isFinished(DateTime.now())) {
      _handling = true;
      final finished = await store.completeFocusIfDue();
      if (mounted && finished != null) await _celebrate(finished, focus);
      _handling = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _start(FocusPhase phase, int minutes) =>
      context.read<AppStore>().startFocus(
        phase: phase,
        minutes: minutes,
        subjectId: _subjectId,
        studyItemId: _studyItemId,
      );

  Future<void> _stop() async {
    final store = context.read<AppStore>();
    final focus = store.focus;
    if (focus == null) return;
    final elapsed = focus.elapsedSeconds(DateTime.now());
    if (focus.phase == FocusPhase.focus && elapsed >= 60) {
      final ok = await confirmDelete(
        context,
        'توقف الجلسة؟',
        message:
            'هيتسجل ${studyTimeText((elapsed / 60).round())} مذاكرة في إحصائياتك.',
        confirmLabel: 'إيقاف',
      );
      if (!ok) return;
    }
    final logged = await store.stopFocus();
    if (mounted && logged != null) {
      showSnack(context, 'اتسجل ${studyTimeText(logged.minutes)} مذاكرة 👏');
    }
  }

  Future<void> _celebrate(FocusPhase finished, FocusState state) async {
    final store = context.read<AppStore>();
    final settings = store.settings;
    if (finished == FocusPhase.rest) {
      final again = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Text('⏰', style: TextStyle(fontSize: 40)),
          title: const Text('البريك خلص', textAlign: TextAlign.center),
          content: const Text('يلا نرجع نذاكر؟', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('كفاية كده'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('جلسة ${settings.focusMinutes} دقيقة'),
            ),
          ],
        ),
      );
      if (again == true) await _start(FocusPhase.focus, settings.focusMinutes);
      return;
    }

    final item = store.studyItems
        .where((s) => s.id == state.studyItemId)
        .firstOrNull;
    var markStudied = false;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          icon: const Text('🎉', style: TextStyle(fontSize: 44)),
          title: const Text('برافو عليك!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ذاكرت ${studyTimeText((state.plannedSeconds / 60).round())} '
                'من غير ما تبطل. خد بريك صغير وارجع 💪',
                textAlign: TextAlign.center,
              ),
              if (item != null && !item.status.isDone)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: markStudied,
                  onChanged: (v) => setDialog(() => markStudied = v ?? false),
                  title: Text('خلصت مذاكرة "${item.title}"'),
                ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'done'),
              child: const Text('خلاص كده'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, 'again'),
              child: const Text('جلسة كمان'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'break'),
              child: Text('بريك ${settings.breakMinutes} د'),
            ),
          ],
        ),
      ),
    );
    if (markStudied && item != null) {
      await store.setStudyStatus(item.id, StudyStatus.studied);
    }
    if (choice == 'break') {
      await _start(FocusPhase.rest, settings.breakMinutes);
    } else if (choice == 'again') {
      await _start(FocusPhase.focus, settings.focusMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final focus = store.focus;
    final now = DateTime.now();
    final resting = focus?.phase == FocusPhase.rest;
    final gradient = resting ? AppColors.tealGradient : AppColors.heroGradient;

    return Scaffold(
      backgroundColor: gradient.colors.first,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Text(
                        resting ? 'بريك ☕' : 'جلسة تركيز',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'الإحصائيات',
                      icon: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => pushPage(context, const StatsScreen()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: focus == null
                    ? _Setup(
                        subjectId: _subjectId,
                        studyItemId: _studyItemId,
                        minutes: _minutes,
                        presets: _presets,
                        onSubject: (id) => setState(() {
                          _subjectId = id;
                          _studyItemId = null;
                        }),
                        onItem: (id) => setState(() => _studyItemId = id),
                        onMinutes: (m) => setState(() => _minutes = m),
                        onStart: () => _start(FocusPhase.focus, _minutes),
                      )
                    : _Running(
                        focus: focus,
                        now: now,
                        onPause: store.pauseFocus,
                        onResume: store.resumeFocus,
                        onStop: _stop,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _Setup extends StatelessWidget {
  const _Setup({
    required this.subjectId,
    required this.studyItemId,
    required this.minutes,
    required this.presets,
    required this.onSubject,
    required this.onItem,
    required this.onMinutes,
    required this.onStart,
  });

  final String? subjectId;
  final String? studyItemId;
  final int minutes;
  final List<int> presets;
  final ValueChanged<String?> onSubject;
  final ValueChanged<String?> onItem;
  final ValueChanged<int> onMinutes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = StudyStats(store.studySessions, DateTime.now());
    final goal = store.settings.dailyGoalMinutes;
    final lectures = subjectId == null
        ? const <StudyItem>[]
        : store
              .studyItemsFor(subjectId!)
              .where((i) => !i.status.isDone)
              .toList();
    const white = Colors.white;

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: selected ? white : white.withValues(alpha: 0.14),
        shape: StadiumBorder(
          side: BorderSide(color: white.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: ProgressRing(
            value: 1,
            size: 230,
            stroke: 14,
            color: white.withValues(alpha: 0.9),
            trackColor: white.withValues(alpha: 0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clock(minutes * 60),
                  style: const TextStyle(
                    color: white,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'جاهز تبدأ؟',
                  style: TextStyle(color: white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'هتذاكر إيه؟',
          style: TextStyle(color: white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('أي حاجة', subjectId == null, () => onSubject(null)),
              for (final s in store.subjects)
                chip(s.name, subjectId == s.id, () => onSubject(s.id)),
            ],
          ),
        ),
        if (lectures.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in lectures)
                  chip(
                    l.title,
                    studyItemId == l.id,
                    () => onItem(studyItemId == l.id ? null : l.id),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'المدة',
          style: TextStyle(color: white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          runSpacing: 8,
          children: [
            for (final m in {...presets, minutes}.toList()..sort())
              chip('$m د', minutes == m, () => onMinutes(m)),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 30),
            label: const Text('يلا نبدأ', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ProgressRing(
                value: stats.today / goal,
                size: 46,
                stroke: 5,
                color: AppColors.amber,
                trackColor: white.withValues(alpha: 0.2),
                child: const Text('🎯'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ذاكرت النهارده ${studyTimeText(stats.today)} '
                  'من هدفك ${studyTimeText(goal)}'
                  '${stats.streak > 1 ? ' • 🔥 ${stats.streak} أيام ورا بعض' : ''}',
                  style: const TextStyle(color: white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.focus,
    required this.now,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final FocusState focus;
  final DateTime now;
  final Future<void> Function([DateTime?]) onPause;
  final Future<void> Function([DateTime?]) onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final subject = store.subjectById(focus.subjectId);
    final item = store.studyItems
        .where((s) => s.id == focus.studyItemId)
        .firstOrNull;
    final remaining = focus.remainingSeconds(now);
    final resting = focus.phase == FocusPhase.rest;
    const white = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),
          Text(
            resting
                ? 'ريّح شوية… اشرب مية واتمشى 🚶'
                : [?subject?.name, ?item?.title].join(' • ').isEmpty
                ? 'ركّز… إنت قدها 🎯'
                : [?subject?.name, ?item?.title].join(' • '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          ProgressRing(
            value: focus.plannedSeconds == 0
                ? 0
                : remaining / focus.plannedSeconds,
            size: 260,
            stroke: 16,
            color: white,
            trackColor: white.withValues(alpha: 0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clock(remaining),
                  style: const TextStyle(
                    color: white,
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  focus.isPaused
                      ? 'متوقف مؤقتاً'
                      : (resting ? 'بريك' : 'تركيز'),
                  style: TextStyle(color: white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: Icons.stop_rounded,
                label: 'إيقاف',
                onTap: onStop,
                filled: false,
              ),
              const SizedBox(width: 28),
              _RoundButton(
                icon: focus.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: focus.isPaused ? 'كمّل' : 'وقفة',
                onTap: () => focus.isPaused ? onResume() : onPause(),
                filled: true,
                big: true,
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              quoteOfTheDay(now),
              textAlign: TextAlign.center,
              style: TextStyle(color: white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 84.0 : 64.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Material(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: size * 0.5,
                  color: filled ? AppColors.primary : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
