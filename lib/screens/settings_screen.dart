import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notifications = NotificationService.instance;
  late final _name = TextEditingController(
    text: context.read<AppStore>().settings.studentName,
  );
  bool? _enabled;
  bool? _exact;
  int? _pending;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final enabled = await _notifications.areEnabled();
    final exact = await _notifications.canScheduleExact();
    final pending = await _notifications.pendingCount();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _exact = exact;
        _pending = pending;
      });
    }
  }

  Future<void> _update(AppSettings s) async {
    await context.read<AppStore>().updateSettings(s);
    // Rescheduling is debounced; give it a moment before refreshing.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _refreshStatus();
  }

  Future<void> _export(AppStore store) async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (mounted) {
      showSnack(
        context,
        'اتنسخت نسخة احتياطية — الصقها في ملاحظة أو ابعتها لنفسك',
      );
    }
  }

  Future<void> _import(AppStore store) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استرجاع نسخة احتياطية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الصق النسخة هنا. كل البيانات الحالية هتتبدل بيها.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(hintText: '{ ... }'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('استرجاع'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      await store.importJson(raw);
      if (mounted) showSnack(context, 'اترجعت البيانات ✓');
    } on FormatException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _clear(AppStore store) async {
    final ok = await confirmDelete(
      context,
      'تمسح كل البيانات؟',
      message:
          'المواد والجدول والمحاضرات والتاسكات والدرجات… كله هيتمسح ومش هيرجع. '
          'خد نسخة احتياطية الأول لو محتاجها.',
    );
    if (!ok) return;
    await store.clearAll();
    if (mounted) showSnack(context, 'اتمسح كل حاجة');
  }

  Future<void> _pickMinutes(
    String title,
    int current,
    List<int> options,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in options)
                    ChoiceChip(
                      label: Text(durationText(Duration(minutes: m))),
                      selected: current == m,
                      showCheckmark: false,
                      onSelected: (_) => Navigator.pop(ctx, m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final theme = Theme.of(context);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    Widget tile({
      required IconData icon,
      required Color color,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
      bool enabled = true,
    }) => ListTile(
      enabled: enabled,
      leading: IconBadge(icon, color: color, size: 40),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );

    Widget group(List<Widget> children) => AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      clip: true,
      child: Column(children: children),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            gradient: AppColors.heroGradient,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Text('🎓', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      labelText: 'اسمك (عشان أناديك بيه)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    cursorColor: Colors.white,
                    onChanged: (v) =>
                        store.updateSettings(s.copyWith(studentName: v.trim())),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('المذاكرة', icon: Icons.auto_stories_rounded),
          group([
            tile(
              icon: Icons.flag_rounded,
              color: AppColors.coral,
              title: 'هدفك اليومي',
              subtitle: 'كام ساعة عايز تذاكر في اليوم',
              trailing: Text(
                studyTimeText(s.dailyGoalMinutes),
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => _pickMinutes(
                'هدفك اليومي',
                s.dailyGoalMinutes,
                const [30, 60, 90, 120, 180, 240, 300, 360, 480],
                (m) => store.updateSettings(s.copyWith(dailyGoalMinutes: m)),
              ),
            ),
            tile(
              icon: Icons.timer_rounded,
              color: AppColors.primary,
              title: 'مدة جلسة التركيز',
              trailing: Text(
                studyTimeText(s.focusMinutes),
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => _pickMinutes(
                'مدة جلسة التركيز',
                s.focusMinutes,
                const [15, 20, 25, 30, 45, 50, 60, 90],
                (m) => store.updateSettings(s.copyWith(focusMinutes: m)),
              ),
            ),
            tile(
              icon: Icons.coffee_rounded,
              color: AppColors.teal,
              title: 'مدة البريك',
              trailing: Text(
                studyTimeText(s.breakMinutes),
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => _pickMinutes('مدة البريك', s.breakMinutes, const [
                3,
                5,
                10,
                15,
                20,
                30,
              ], (m) => store.updateSettings(s.copyWith(breakMinutes: m))),
            ),
          ]),
          const SectionHeader('نظام التقدير', icon: Icons.grade_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<GradingSystem>(
                  segments: const [
                    ButtonSegment(
                      value: GradingSystem.percentage,
                      label: Text('تقديرات'),
                      icon: Icon(Icons.percent_rounded),
                    ),
                    ButtonSegment(
                      value: GradingSystem.gpa,
                      label: Text('نظام GPA'),
                      icon: Icon(Icons.school_rounded),
                    ),
                  ],
                  selected: {s.gradingSystem},
                  onSelectionChanged: (v) =>
                      store.updateSettings(s.copyWith(gradingSystem: v.first)),
                ),
                const SizedBox(height: 8),
                Text(
                  s.gradingSystem == GradingSystem.gpa
                      ? 'A من 90% • B من 75% • C من 60% • D من 50% — والمعدل بيتحسب بالساعات المعتمدة لكل مادة'
                      : 'ممتاز من 85% • جيد جداً من 75% • جيد من 65% • مقبول من 50%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            'الإشعارات',
            icon: Icons.notifications_active_rounded,
          ),
          if (_enabled == false)
            AppCard(
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_rounded),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'الإشعارات مقفولة للتطبيق — من غيرها مش هقدر أفكرك بالمحاضرات',
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(70, 40),
                    ),
                    onPressed: () async {
                      await _notifications.requestPermission();
                      await _refreshStatus();
                    },
                    child: const Text('تفعيل'),
                  ),
                ],
              ),
            ),
          if (isAndroid && _exact == false)
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'خلي التنبيه ييجي في معاده بالظبط — من غير الإذن ده أندرويد ممكن يأخره كام دقيقة',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _notifications.requestExactAlarms();
                      await _refreshStatus();
                    },
                    child: const Text('سماح'),
                  ),
                ],
              ),
            ),
          group([
            SwitchListTile(
              secondary: const IconBadge(
                Icons.notifications_active_rounded,
                color: AppColors.primary,
                size: 40,
              ),
              title: const Text(
                'تشغيل كل الإشعارات',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: s.notificationsEnabled,
              onChanged: (v) => _update(s.copyWith(notificationsEnabled: v)),
            ),
            tile(
              enabled: s.notificationsEnabled,
              icon: Icons.schedule_rounded,
              color: AppColors.sky,
              title: 'التنبيه قبل المحاضرة',
              subtitle: 'للمواعيد الجديدة في الجدول',
              trailing: DropdownButton<int>(
                value: classReminderOptions.contains(s.defaultClassReminder)
                    ? s.defaultClassReminder
                    : 15,
                underline: const SizedBox.shrink(),
                onChanged: s.notificationsEnabled
                    ? (v) => _update(s.copyWith(defaultClassReminder: v))
                    : null,
                items: [
                  for (final m in classReminderOptions)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m == 0 ? 'وقتها' : reminderText(m)),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const IconBadge(
                Icons.wb_sunny_rounded,
                color: AppColors.orange,
                size: 40,
              ),
              title: const Text(
                'ملخص اليوم الصبح',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'كل يوم الساعة ${formatMinuteOfDay(s.dailySummaryMinute)}: '
                'جدولك وكويزاتك ومراجعاتك',
              ),
              value: s.dailySummaryEnabled && s.notificationsEnabled,
              onChanged: s.notificationsEnabled
                  ? (v) => _update(s.copyWith(dailySummaryEnabled: v))
                  : null,
            ),
            if (s.dailySummaryEnabled && s.notificationsEnabled)
              tile(
                icon: Icons.access_time_rounded,
                color: AppColors.orange,
                title: 'معاد الملخص',
                trailing: Text(
                  formatMinuteOfDay(s.dailySummaryMinute),
                  style: theme.textTheme.titleSmall,
                ),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: s.dailySummaryMinute ~/ 60,
                      minute: s.dailySummaryMinute % 60,
                    ),
                  );
                  if (t != null) {
                    await _update(
                      s.copyWith(dailySummaryMinute: t.hour * 60 + t.minute),
                    );
                  }
                },
              ),
            tile(
              icon: Icons.send_rounded,
              color: AppColors.teal,
              title: 'جرّب إشعار دلوقتي',
              subtitle: _pending == null ? null : 'فيه $_pending تنبيه متجدول',
              onTap: () async {
                await _notifications.requestPermission();
                await _notifications.showTest();
                await _refreshStatus();
              },
            ),
          ]),
          const SectionHeader('الشكل', icon: Icons.palette_rounded),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text('زي الموبايل'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text('فاتح'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text('غامق'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) =>
                store.updateSettings(s.copyWith(themeMode: v.first)),
          ),
          const SectionHeader('البيانات', icon: Icons.storage_rounded),
          group([
            tile(
              icon: Icons.copy_all_rounded,
              color: AppColors.sky,
              title: 'نسخة احتياطية',
              subtitle: 'انسخ كل بياناتك كنص تحتفظ بيه',
              onTap: () => _export(store),
            ),
            tile(
              icon: Icons.restore_rounded,
              color: AppColors.teal,
              title: 'استرجاع نسخة احتياطية',
              onTap: () => _import(store),
            ),
            tile(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.primary,
              title: 'تحميل بيانات تجريبية',
              subtitle: 'عشان تجرب التطبيق (هتمسح بياناتك الحالية)',
              onTap: () async {
                final ok =
                    store.isEmpty ||
                    await confirmDelete(
                      context,
                      'تبدل بياناتك ببيانات تجريبية؟',
                      message: 'بياناتك الحالية هتتمسح.',
                      confirmLabel: 'تبديل',
                    );
                if (!ok) return;
                await loadDemoData(store, DateTime.now());
                if (context.mounted) {
                  showSnack(context, 'اتحملت البيانات التجريبية');
                }
              },
            ),
            tile(
              icon: Icons.delete_forever_rounded,
              color: AppColors.danger,
              title: 'مسح كل البيانات',
              onTap: () => _clear(store),
            ),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'منظم دراستي • كل بياناتك محفوظة على موبايلك بس 🔒',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
