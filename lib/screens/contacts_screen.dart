import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';
import 'notes_screen.dart';

extension ContactRoleLabel on ContactRole {
  String get label => switch (this) {
    ContactRole.doctor => 'دكتور',
    ContactRole.assistant => 'معيد',
    ContactRole.classmate => 'زميل',
    ContactRole.staff => 'موظف',
    ContactRole.other => 'حد تاني',
  };

  Color get color => switch (this) {
    ContactRole.doctor => AppColors.primary,
    ContactRole.assistant => AppColors.sky,
    ContactRole.classmate => AppColors.teal,
    ContactRole.staff => AppColors.orange,
    ContactRole.other => AppColors.bonus,
  };
}

/// "الأحد 10:00 ص – 12:00 م".
String slotText(WeeklySlot s) =>
    '${weekdayNames[s.weekday]} ${formatMinuteOfDay(s.startMinute)} – '
    '${formatMinuteOfDay(s.endMinute)}';

/// A phone number as digits only, with Egypt's code for WhatsApp links.
String _whatsAppNumber(String phone) {
  var digits = latinDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '2$digits';
  return digits;
}

/// Doctors, teaching assistants, classmates, and study groups.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  ContactRole? _role;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final onGroups = _tabs.index == 1;
    final people = store
        .contactsFor()
        .where((c) => _role == null || c.role == _role)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدكاترة والزمايل'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الناس'),
            Tab(text: 'المجموعات'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'contacts-fab',
        onPressed: () => pushPage(
          context,
          onGroups ? const GroupForm() : const ContactForm(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(onGroups ? 'مجموعة' : 'شخص'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _role == null,
                      onSelected: (_) => setState(() => _role = null),
                    ),
                    for (final r in ContactRole.values) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _role == r,
                        onSelected: (_) => setState(() => _role = r),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (people.isEmpty)
                const EmptyState(
                  icon: Icons.contacts_rounded,
                  title: 'لسه مفيش حد',
                  message:
                      'سجل الدكاترة والمعيدين بمكاتبهم ومواعيد الـ Office '
                      'Hours، وأرقام زمايلك، وتواصل معاهم بضغطة',
                )
              else
                for (final c in people) ContactTile(contact: c),
            ],
          ),
          _GroupsTab(store: store),
        ],
      ),
    );
  }
}

/// A person with buttons to call, message on WhatsApp or email them.
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    final c = contact;
    final subjects = [
      for (final id in c.subjectIds)
        if (store.subjectById(id) != null) store.subjectById(id)!.name,
    ];
    final initial = c.name.trim().isEmpty ? '؟' : c.name.trim()[0];
    return AppCard(
      onTap: () => pushPage(context, ContactForm(contact: c)),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: c.role.color.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: c.role.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [c.role.label, ...subjects].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.office.isNotEmpty || c.officeHours.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (c.office.isNotEmpty) 'المكتب: ${c.office}',
                for (final s in c.officeHours) slotText(s),
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (c.phone.isNotEmpty || c.email.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (c.phone.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'اتصل',
                    icon: const Icon(Icons.call_rounded),
                    onPressed: () => openLink(
                      context,
                      'tel:${latinDigits(c.phone).replaceAll(' ', '')}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'واتساب',
                    icon: const Icon(Icons.chat_rounded),
                    onPressed: () => openLink(
                      context,
                      'https://wa.me/${_whatsAppNumber(c.phone)}',
                    ),
                  ),
                ],
                if (c.email.isNotEmpty)
                  IconButton(
                    tooltip: 'إيميل',
                    icon: const Icon(Icons.mail_rounded),
                    onPressed: () => openLink(context, 'mailto:${c.email}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final groups = [...store.groups]..sort((a, b) => a.name.compareTo(b.name));
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_rounded,
        title: 'مفيش مجموعات',
        message: 'جروب مذاكرة أو فريق مشروع: مين فيه ولينك الجروب في مكان واحد',
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (final g in groups)
          AppCard(
            onTap: () => pushPage(context, GroupForm(group: g)),
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                const IconBadge(Icons.groups_rounded, color: AppColors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (store.subjectById(g.subjectId) != null)
                            store.subjectById(g.subjectId)!.name,
                          if (g.memberIds.isNotEmpty)
                            [
                              for (final id in g.memberIds)
                                if (store.contactById(id) != null)
                                  store.contactById(id)!.name,
                            ].join('، '),
                        ].join(' • '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (g.link.isNotEmpty)
                  IconButton(
                    tooltip: 'افتح الجروب',
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: () => openLink(context, g.link),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Adds or edits a person.
class ContactForm extends StatefulWidget {
  const ContactForm({super.key, this.contact, this.initialSubjectId});

  final Contact? contact;
  final String? initialSubjectId;

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.contact?.name);
  late final _phone = TextEditingController(text: widget.contact?.phone);
  late final _email = TextEditingController(text: widget.contact?.email);
  late final _office = TextEditingController(text: widget.contact?.office);
  late final _notes = TextEditingController(text: widget.contact?.notes);
  late ContactRole _role = widget.contact?.role ?? ContactRole.doctor;
  late final Set<String> _subjects = {
    ...?widget.contact?.subjectIds,
    ?widget.initialSubjectId,
  };
  late final List<WeeklySlot> _hours = [...?widget.contact?.officeHours];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _office.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppStore>().saveContact(
      Contact(
        id: widget.contact?.id ?? newId(),
        name: _name.text.trim(),
        role: _role,
        subjectIds: _subjects.toList(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        office: _office.text.trim(),
        officeHours: _hours,
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح "${widget.contact!.name}"؟')) {
      return;
    }
    if (!mounted) return;
    await context.read<AppStore>().deleteContact(widget.contact!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.contact != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل' : 'شخص جديد'),
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
              Wrap(
                spacing: 8,
                children: [
                  for (final r in ContactRole.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _name,
                autofocus: !editing,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
              ),
              formGap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الموبايل',
                  prefixIcon: Icon(Icons.call_rounded),
                ),
              ),
              formGap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الإيميل',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              if (store.subjects.isNotEmpty) ...[
                formGap,
                Text('المواد', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final s in store.subjects)
                      FilterChip(
                        label: Text(s.name),
                        selected: _subjects.contains(s.id),
                        onSelected: (on) => setState(
                          () =>
                              on ? _subjects.add(s.id) : _subjects.remove(s.id),
                        ),
                      ),
                  ],
                ),
              ],
              formGap,
              TextFormField(
                controller: _office,
                decoration: const InputDecoration(
                  labelText: 'المكتب',
                  prefixIcon: Icon(Icons.meeting_room_rounded),
                ),
              ),
              formGap,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'مواعيد الـ Office Hours',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _hours.add(
                        const WeeklySlot(
                          weekday: DateTime.sunday,
                          startMinute: 10 * 60,
                          endMinute: 12 * 60,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('ميعاد'),
                  ),
                ],
              ),
              for (var i = 0; i < _hours.length; i++)
                _SlotRow(
                  slot: _hours[i],
                  onChanged: (s) => setState(() => _hours[i] = s),
                  onRemove: () => setState(() => _hours.removeAt(i)),
                ),
              formGap,
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.notes),
                ),
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

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.onChanged,
    required this.onRemove,
  });

  final WeeklySlot slot;
  final ValueChanged<WeeklySlot> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // The week starts on Saturday at Egyptian universities.
    const days = [6, 7, 1, 2, 3, 4, 5];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          DropdownButton<int>(
            value: slot.weekday,
            items: [
              for (final d in days)
                DropdownMenuItem(value: d, child: Text(weekdayNames[d]!)),
            ],
            onChanged: (d) => onChanged(
              WeeklySlot(
                weekday: d ?? slot.weekday,
                startMinute: slot.startMinute,
                endMinute: slot.endMinute,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TimeField(
              label: 'من',
              minuteOfDay: slot.startMinute,
              onChanged: (m) => onChanged(
                WeeklySlot(
                  weekday: slot.weekday,
                  startMinute: m,
                  endMinute: slot.endMinute < m ? m : slot.endMinute,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TimeField(
              label: 'لحد',
              minuteOfDay: slot.endMinute,
              onChanged: (m) => onChanged(
                WeeklySlot(
                  weekday: slot.weekday,
                  startMinute: slot.startMinute,
                  endMinute: m < slot.startMinute ? slot.startMinute : m,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'شيل',
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Adds or edits a study group or project team.
class GroupForm extends StatefulWidget {
  const GroupForm({super.key, this.group});

  final StudyGroup? group;

  @override
  State<GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<GroupForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group?.name);
  late final _link = TextEditingController(text: widget.group?.link);
  late final _notes = TextEditingController(text: widget.group?.notes);
  late String? _subjectId = widget.group?.subjectId;
  late final Set<String> _members = {...?widget.group?.memberIds};

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppStore>().saveGroup(
      StudyGroup(
        id: widget.group?.id ?? newId(),
        name: _name.text.trim(),
        subjectId: _subjectId,
        memberIds: _members.toList(),
        link: _link.text.trim().isEmpty ? '' : normalizeUrl(_link.text),
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح المجموعة دي؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteGroup(widget.group!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.group != null;
    final people = store.contactsFor();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المجموعة' : 'مجموعة جديدة'),
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
                controller: _name,
                autofocus: !editing,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
              ),
              formGap,
              SubjectPicker(
                value: _subjectId,
                required: false,
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              formGap,
              TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'لينك الجروب (واتساب، تليجرام…)',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              formGap,
              Text('مين فيها', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              if (people.isEmpty)
                const Text('ضيف الناس الأول من تبويب "الناس"')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in people)
                      FilterChip(
                        label: Text(c.name),
                        selected: _members.contains(c.id),
                        onSelected: (on) => setState(
                          () => on ? _members.add(c.id) : _members.remove(c.id),
                        ),
                      ),
                  ],
                ),
              formGap,
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (مين بيعمل إيه…)',
                  prefixIcon: Icon(Icons.notes),
                ),
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
