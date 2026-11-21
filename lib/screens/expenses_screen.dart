import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';
import 'career_screen.dart' show monthNames;

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
    ExpenseCategory.university => 'مصاريف الجامعة',
    ExpenseCategory.books => 'كتب ومذكرات',
    ExpenseCategory.transport => 'مواصلات',
    ExpenseCategory.food => 'أكل وشرب',
    ExpenseCategory.housing => 'سكن',
    ExpenseCategory.phone => 'نت وموبايل',
    ExpenseCategory.courses => 'كورسات',
    ExpenseCategory.fun => 'خروج وترفيه',
    ExpenseCategory.clothes => 'لبس',
    ExpenseCategory.health => 'صحة',
    ExpenseCategory.other => 'حاجات تانية',
  };

  IconData get icon => switch (this) {
    ExpenseCategory.university => Icons.account_balance_rounded,
    ExpenseCategory.books => Icons.menu_book_rounded,
    ExpenseCategory.transport => Icons.directions_bus_rounded,
    ExpenseCategory.food => Icons.restaurant_rounded,
    ExpenseCategory.housing => Icons.home_rounded,
    ExpenseCategory.phone => Icons.wifi_rounded,
    ExpenseCategory.courses => Icons.play_lesson_rounded,
    ExpenseCategory.fun => Icons.celebration_rounded,
    ExpenseCategory.clothes => Icons.checkroom_rounded,
    ExpenseCategory.health => Icons.local_hospital_rounded,
    ExpenseCategory.other => Icons.category_rounded,
  };

  Color get color => switch (this) {
    ExpenseCategory.university => AppColors.primary,
    ExpenseCategory.books => AppColors.sky,
    ExpenseCategory.transport => AppColors.orange,
    ExpenseCategory.food => AppColors.coral,
    ExpenseCategory.housing => AppColors.bonus,
    ExpenseCategory.phone => AppColors.cyan,
    ExpenseCategory.courses => AppColors.teal,
    ExpenseCategory.fun => AppColors.pink,
    ExpenseCategory.clothes => AppColors.amber,
    ExpenseCategory.health => AppColors.danger,
    ExpenseCategory.other => const Color(0xFF9A98B0),
  };
}

/// "1,250 ج.م".
String money(double v) {
  final whole = v.round().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final text = v == v.roundToDouble() ? grouped : formatNumber(v);
  return ltr('$text ج.م');
}

/// Everything spent, month by month, by category.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final items = store.expensesIn(_month);
    final total = items.fold(0.0, (s, e) => s + e.amount);
    final previous = store
        .expensesIn(DateTime(_month.year, _month.month - 1))
        .fold(0.0, (s, e) => s + e.amount);
    final byCategory = <ExpenseCategory, double>{};
    for (final e in items) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final days = isCurrent
        ? now.day
        : DateTime(_month.year, _month.month + 1, 0).day;

    // Items grouped by day, newest first.
    final byDay = <DateTime, List<Expense>>{};
    for (final e in items) {
      byDay.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses-fab',
        onPressed: () => pushPage(
          context,
          ExpenseForm(initialDate: isCurrent ? null : _month),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مصروف'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'الشهر اللي فات',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Text(
                  latinDigits('${monthNames[_month.month]} ${_month.year}'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'الشهر اللي بعده',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: isCurrent ? null : () => _shift(1),
              ),
            ],
          ),
          AppCard(
            gradient: AppColors.heroGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'صرفت الشهر ده',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  money(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    if (total > 0) 'في المتوسط ${money(total / days)} في اليوم',
                    if (previous > 0) 'الشهر اللي فات ${money(previous)}',
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SectionHeader('على إيه؟', icon: Icons.pie_chart_rounded),
            AppCard(
              child: Column(
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(c.key.icon, size: 18, color: c.key.color),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.key.label)),
                              Text(
                                '${money(c.value)} • ${(c.value / total * 100).round()}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RoundedProgress(
                            value: c.value / total,
                            color: c.key.color,
                            height: 6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: 'مفيش مصاريف الشهر ده',
              message: 'سجل اللي بتصرفه أول بأول وشوف فلوسك بتروح فين',
            ),
          for (final day in byDay.keys) ...[
            SectionHeader(
              '${friendlyDay(day, now)} • ${money(byDay[day]!.fold(0.0, (s, e) => s + e.amount))}',
              icon: Icons.today_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in byDay[day]!)
                    ListTile(
                      onTap: () => pushPage(context, ExpenseForm(expense: e)),
                      leading: IconBadge(
                        e.category.icon,
                        color: e.category.color,
                        size: 38,
                      ),
                      title: Text(e.title.isEmpty ? e.category.label : e.title),
                      subtitle: e.title.isEmpty ? null : Text(e.category.label),
                      trailing: Text(
                        money(e.amount),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Adds or edits an expense.
class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, this.expense, this.initialDate});

  final Expense? expense;
  final DateTime? initialDate;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.expense == null ? '' : formatNumber(widget.expense!.amount),
  );
  late final _title = TextEditingController(text: widget.expense?.title);
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.transport;
  late DateTime _date =
      widget.expense?.date ?? dateOnly(widget.initialDate ?? DateTime.now());
  late String? _subjectId = widget.expense?.subjectId;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppStore>().saveExpense(
      Expense(
        id: widget.expense?.id ?? newId(),
        amount: parseNumber(_amount.text)!,
        category: _category,
        title: _title.text.trim(),
        date: _date,
        subjectId: _subjectId,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح المصروف ده؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteExpense(widget.expense!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.expense != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المصروف' : 'مصروف جديد'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _amount,
                autofocus: !editing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (جنيه)',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                validator: (v) {
                  final n = parseNumber(v ?? '');
                  if (n == null || n <= 0) return 'اكتب المبلغ';
                  return null;
                },
              ),
              formGap,
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final c in ExpenseCategory.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: c.color),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'على إيه؟ (اختياري)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              formGap,
              DateTimeField(
                label: 'يوم',
                value: _date,
                withTime: false,
                onChanged: (d) => setState(() => _date = d ?? _date),
              ),
              formGap,
              SubjectPicker(
                value: _subjectId,
                required: false,
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
