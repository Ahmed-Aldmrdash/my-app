import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final theme = Theme.of(context);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسمك (عشان أناديك بيه)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (v) =>
                  store.updateSettings(s.copyWith(studentName: v.trim())),
            ),
          ),
          const SectionHeader('الإشعارات'),
          if (_enabled == false)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('الإشعارات مقفولة للتطبيق'),
                subtitle: const Text('من غيرها مش هقدر أفكرك بالمحاضرات'),
                trailing: FilledButton(
                  onPressed: () async {
                    await _notifications.requestPermission();
                    await _refreshStatus();
                  },
                  child: const Text('تفعيل'),
                ),
              ),
            ),
          if (isAndroid && _exact == false)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: const Text('خلي التنبيه ييجي في معاده بالظبط'),
                subtitle: const Text(
                  'من غير الإذن ده أندرويد ممكن يأخر الإشعار كام دقيقة',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await _notifications.requestExactAlarms();
                    await _refreshStatus();
                  },
                  child: const Text('سماح'),
                ),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('تشغيل كل الإشعارات'),
            value: s.notificationsEnabled,
            onChanged: (v) => _update(s.copyWith(notificationsEnabled: v)),
          ),
          ListTile(
            enabled: s.notificationsEnabled,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('التنبيه الافتراضي قبل المحاضرة'),
            subtitle: const Text('للمواعيد الجديدة اللي هتضيفها للجدول'),
            trailing: DropdownButton<int>(
              value: classReminderOptions.contains(s.defaultClassReminder)
                  ? s.defaultClassReminder
                  : 15,
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
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('ملخص اليوم الصبح'),
            subtitle: Text(
              'إشعار كل يوم الساعة ${formatMinuteOfDay(s.dailySummaryMinute)} '
              'فيه جدولك وكويزاتك وتاسكاتك',
            ),
            value: s.dailySummaryEnabled && s.notificationsEnabled,
            onChanged: s.notificationsEnabled
                ? (v) => _update(s.copyWith(dailySummaryEnabled: v))
                : null,
          ),
          if (s.dailySummaryEnabled && s.notificationsEnabled)
            ListTile(
              leading: const SizedBox(),
              title: const Text('معاد الملخص'),
              trailing: Text(formatMinuteOfDay(s.dailySummaryMinute)),
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
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('جرّب إشعار دلوقتي'),
            subtitle: _pending == null
                ? null
                : Text('فيه $_pending تنبيه متجدول'),
            onTap: () async {
              await _notifications.requestPermission();
              await _notifications.showTest();
              await _refreshStatus();
            },
          ),
          const SectionHeader('الشكل'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('زي الموبايل'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('فاتح'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('غامق'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) =>
                  store.updateSettings(s.copyWith(themeMode: v.first)),
            ),
          ),
          const SectionHeader('البيانات'),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('نسخة احتياطية'),
            subtitle: const Text('انسخ كل بياناتك كنص تحتفظ بيه'),
            onTap: () => _export(store),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استرجاع نسخة احتياطية'),
            onTap: () => _import(store),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('تحميل بيانات تجريبية'),
            subtitle: const Text('عشان تجرب التطبيق (هتمسح بياناتك الحالية)'),
            onTap: () async {
              final ok =
                  store.isEmpty ||
                  await confirmDelete(
                    context,
                    'تبدل بياناتك ببيانات تجريبية؟',
                    message: 'بياناتك الحالية هتتمسح.',
                  );
              if (!ok) return;
              await loadDemoData(store, DateTime.now());
              if (context.mounted) {
                showSnack(context, 'اتحملت البيانات التجريبية');
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'مسح كل البيانات',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _clear(store),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'منظم دراستي • كل بياناتك محفوظة على موبايلك بس',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
