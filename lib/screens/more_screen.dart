import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'academic_screen.dart';
import 'app_tabs.dart';
import 'dashboard_screen.dart';
import 'finals_screen.dart';
import 'flashcards_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'sync_screen.dart';

/// Everything that doesn't fit in the bottom bar: the subjects, the other
/// sections of the app and its settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.onNavigate});

  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, IconData, List<MoreEntry>)>[
      (
        'الدراسة',
        Icons.school_rounded,
        [
          MoreEntry(
            icon: Icons.school_rounded,
            color: AppColors.primary,
            title: 'المواد والدرجات',
            subtitle: 'درجاتك وحضورك في كل مادة',
            onTap: () => onNavigate(AppTabs.subjects),
          ),
          MoreEntry(
            icon: Icons.workspace_premium_rounded,
            color: AppColors.coral,
            title: 'الفاينال',
            subtitle: 'جدول الامتحانات وخطة المذاكرة',
            onTap: () => pushPage(context, const FinalsScreen()),
          ),
          MoreEntry(
            icon: Icons.sticky_note_2_rounded,
            color: AppColors.amber,
            title: 'الملاحظات واللينكات',
            subtitle: 'درايف ويوتيوب و PDF لكل مادة',
            onTap: () => pushPage(context, const NotesScreen()),
          ),
          MoreEntry(
            icon: Icons.style_rounded,
            color: AppColors.cyan,
            title: 'الفلاش كاردز',
            subtitle: 'سؤال وجواب ومراجعة في ميعادها',
            onTap: () => pushPage(context, const FlashcardsScreen()),
          ),
          MoreEntry(
            icon: Icons.history_edu_rounded,
            color: AppColors.sky,
            title: 'الترمات وخطة التخرج',
            subtitle: 'المعدل التراكمي وفاضلك كام',
            onTap: () => pushPage(context, const AcademicScreen()),
          ),
          MoreEntry(
            icon: Icons.insights_rounded,
            color: AppColors.teal,
            title: 'الإحصائيات',
            subtitle: 'وقت مذاكرتك وأيامك المتتالية',
            onTap: () => pushPage(context, const StatsScreen()),
          ),
        ],
      ),
      (
        'التطبيق',
        Icons.tune_rounded,
        [
          MoreEntry(
            icon: Icons.cloud_sync_rounded,
            color: AppColors.sky,
            title: 'المزامنة',
            subtitle: 'بين الموبايل والكمبيوتر',
            onTap: () => pushPage(context, const SyncScreen()),
          ),
          MoreEntry(
            icon: Icons.settings_rounded,
            color: AppColors.orange,
            title: 'الإعدادات',
            subtitle: 'اسمك وهدفك والإشعارات',
            onTap: () => pushPage(context, const SettingsScreen()),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          for (final (title, icon, entries) in groups) ...[
            SectionHeader(title, icon: icon),
            MoreGrid(entries: entries),
          ],
        ],
      ),
    );
  }
}

/// One section of the app, shown as a card in [MoreScreen].
class MoreEntry {
  const MoreEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Cards in two columns on phones and three on wider screens.
class MoreGrid extends StatelessWidget {
  const MoreGrid({super.key, required this.entries});

  final List<MoreEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < entries.length; i += columns) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) const SizedBox(width: 10),
                    Expanded(
                      child: j < entries.length
                          ? _MoreCard(entries[j])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard(this.entry);

  final MoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: entry.onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(entry.icon, color: entry.color, size: 40),
          const SizedBox(height: 10),
          Text(
            entry.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
