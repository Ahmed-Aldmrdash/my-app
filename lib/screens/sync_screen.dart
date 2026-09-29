import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../sync/setup_sql.dart';
import '../sync/sync_config.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// Sets up and shows syncing between the student's devices.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _editProject = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<SyncService>().config;
    if (config != null) {
      _url.text = config.url;
      _key.text = config.key;
    }
  }

  @override
  void dispose() {
    for (final c in [_url, _key, _code, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _show(String? message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProject(SyncService sync) => _run(() async {
    SyncConfig config;
    if (_code.text.trim().isNotEmpty) {
      final fromCode = SyncConfig.fromLinkCode(_code.text);
      if (fromCode == null) {
        _show('كود الربط مش صحيح — انسخه تاني كامل', error: true);
        return;
      }
      config = fromCode;
    } else {
      try {
        config = SyncConfig.parse(_url.text, _key.text);
      } on FormatException catch (e) {
        _show(e.message, error: true);
        return;
      }
    }
    final error = await sync.configure(config);
    if (error != null) {
      _show(error, error: true);
    } else {
      _editProject = false;
      _url.text = config.url;
      _key.text = config.key;
      _show('اتصلت بالمشروع ✓ — دلوقتي ادخل بحسابك أو اعمل حساب جديد');
    }
  });

  Future<void> _auth(SyncService sync, {required bool create}) =>
      _run(() async {
        final email = _email.text.trim();
        if (!email.contains('@')) {
          _show('اكتب إيميلك صح', error: true);
          return;
        }
        if (_password.text.length < 6) {
          _show('الباسورد لازم 6 حروف أو أرقام على الأقل', error: true);
          return;
        }
        final result = create
            ? await sync.signUp(email, _password.text)
            : await sync.signIn(email, _password.text);
        if (result == null) {
          _password.clear();
          _show(
            create
                ? 'اتعمل حسابك ✓ وبيانات الجهاز ده بتترفع دلوقتي'
                : 'دخلت ✓ وبجيب بياناتك من الأجهزة التانية',
          );
        } else {
          _show(result, error: !result.contains('إيميل تأكيد'));
        }
      });

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final state = sync.state;
    final showSetup =
        _editProject ||
        state == SyncState.notConfigured ||
        (state == SyncState.error && !sync.isSignedIn);

    return Scaffold(
      appBar: AppBar(title: const Text('المزامنة بين الأجهزة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _StatusCard(sync: sync),
          if (_message != null)
            AppCard(
              color: _messageIsError
                  ? AppColors.danger.withValues(alpha: 0.10)
                  : AppColors.success.withValues(alpha: 0.10),
              child: Row(
                children: [
                  Icon(
                    _messageIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _messageIsError
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_message!)),
                ],
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (showSetup)
            _setupSection(context, sync)
          else if (state == SyncState.connecting)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!sync.isSignedIn)
            _loginSection(context, sync)
          else
            _accountSection(context, sync),
        ],
      ),
    );
  }

  Widget _setupSection(BuildContext context, SyncService sync) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'تجهيز مرة واحدة بس',
          icon: Icons.rocket_launch_rounded,
          children: [
            Text(
              'المزامنة محتاجة مكان على النت تتحفظ فيه بياناتك. هتعمل مشروع '
              'مجاني على Supabase (حوالي 5 دقايق)، وبعد كده أي حاجة تضيفها على '
              'الموبايل تظهر على الكمبيوتر والعكس.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showSetupSteps(context),
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('خطوات التجهيز بالتفصيل'),
            ),
          ],
        ),
        FormSection(
          title: 'بيانات المشروع',
          icon: Icons.cloud_rounded,
          children: [
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط المشروع (Project URL)',
                hintText: 'https://xxxx.supabase.co',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            formGap,
            TextField(
              controller: _key,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'المفتاح (Publishable key)',
                hintText: 'sb_publishable_...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('أو', style: theme.textTheme.labelLarge),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'كود الربط من جهازك التاني',
                hintText: 'SP1:...',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _saveProject(sync),
              icon: const Icon(Icons.cloud_done_rounded),
              label: const Text('حفظ واتصال'),
            ),
            if (_editProject)
              TextButton(
                onPressed: () => setState(() => _editProject = false),
                child: const Text('إلغاء'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _loginSection(BuildContext context, SyncService sync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'ادخل بحسابك',
          icon: Icons.person_rounded,
          children: [
            Text(
              'استخدم نفس الإيميل والباسورد على الموبايل والكمبيوتر. '
              'لو دي أول مرة دوس "عمل حساب جديد".',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (context.select<AppStore, bool>((s) => s.onlyDemoData)) ...[
              formGap,
              AppCard(
                color: AppColors.amber.withValues(alpha: 0.14),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.amber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'البيانات التجريبية اللي على الجهاز ده هتتشال أول ما '
                        'تدخل، عشان متتخلطش ببياناتك الحقيقية.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            formGap,
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'الإيميل',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            formGap,
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'الباسورد',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'إظهار' : 'إخفاء',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              onSubmitted: (_) => _auth(sync, create: false),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _auth(sync, create: false),
              icon: const Icon(Icons.login_rounded),
              label: const Text('دخول'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _auth(sync, create: true),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('عمل حساب جديد'),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => setState(() => _editProject = true),
          icon: const Icon(Icons.settings_rounded),
          label: const Text('غيّر بيانات المشروع'),
        ),
      ],
    );
  }

  Widget _accountSection(BuildContext context, SyncService sync) {
    final theme = Theme.of(context);
    final code = sync.config?.toLinkCode();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'حسابك',
          icon: Icons.person_rounded,
          children: [
            Row(
              children: [
                const IconBadge(
                  Icons.alternate_email_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sync.email ?? '',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'الجهاز ده هيفضل داخل على حسابك، ومش محتاج تعمل حاجة تاني: '
              'التعديلات بتتزامن لوحدها.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: sync.state == SyncState.syncing
                  ? null
                  : () => sync.syncNow(),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('زامن دلوقتي'),
            ),
          ],
        ),
        if (code != null)
          FormSection(
            title: 'على جهازك التاني',
            icon: Icons.devices_rounded,
            children: [
              Text(
                'افتح التطبيق على الجهاز التاني ← الإعدادات ← المزامنة، والصق '
                'الكود ده في "كود الربط"، وبعدين ادخل بنفس الإيميل والباسورد.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  code,
                  textDirection: TextDirection.ltr,
                  maxLines: 3,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    showSnack(context, 'اتنسخ كود الربط — ابعته لنفسك');
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ كود الربط'),
              ),
            ],
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () async {
            final ok = await confirmDelete(
              context,
              'تخرج من الحساب على الجهاز ده؟',
              message:
                  'بياناتك هتفضل على الجهاز ده وعلى حسابك، بس مش هتتزامن لحد ما تدخل تاني.',
              confirmLabel: 'خروج',
            );
            if (ok) await sync.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('خروج من الحساب'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sync});

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (sync.state) {
      SyncState.notConfigured => (
        Icons.cloud_off_rounded,
        'المزامنة مش شغالة',
        'جهّزها مرة واحدة وبياناتك تبقى واحدة على الموبايل والكمبيوتر',
      ),
      SyncState.connecting => (Icons.cloud_queue_rounded, 'بتصل…', 'ثواني'),
      SyncState.signedOut => (
        Icons.cloud_queue_rounded,
        'السيرفر جاهز',
        'ادخل بحسابك عشان بياناتك تتزامن',
      ),
      SyncState.syncing => (
        Icons.cloud_sync_rounded,
        'بزامن…',
        'برفع تعديلاتك وبجيب الجديد',
      ),
      SyncState.idle => (
        Icons.cloud_done_rounded,
        'متزامن ✓',
        'شغالة لوحدها: أي تعديل بيوصل لأجهزتك التانية على طول'
            '${sync.lastSynced == null ? '' : ' • آخر مزامنة ${_ago(sync.lastSynced!)}'}',
      ),
      SyncState.error => (
        Icons.cloud_off_rounded,
        'فيه مشكلة في المزامنة',
        sync.error ?? '',
      ),
    };
    return AppCard(
      gradient: sync.state == SyncState.error
          ? const LinearGradient(colors: [Color(0xFFE17055), Color(0xFFFF7675)])
          : AppColors.heroGradient,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'من ثواني';
    return 'من ${durationText(d)}';
  }
}

/// Step-by-step guide to create the free Supabase project.
Future<void> showSetupSteps(BuildContext context) {
  const steps = [
    'ادخل supabase.com ودوس "Start your project"، وسجّل دخول بحساب GitHub بتاعك.',
    'دوس "New project": اكتب اسم (مثلاً study-planner) وباسورد للداتابيز، واختار المنطقة Frankfurt (الأقرب لمصر)، ودوس Create واستنى دقيقتين.',
    'من القايمة اللي على الجنب افتح "SQL Editor"، الصق كود الـ SQL (زرار النسخ تحت) ودوس Run. لازم تظهر Success.',
    'افتح Authentication ← Sign In / Providers ← Email، واقفل "Confirm email" ودوس Save — عشان الحساب يشتغل على طول من غير إيميل تأكيد.',
    'دوس زرار "Connect" اللي فوق (أو Project Settings ← API Keys): انسخ الـ Project URL والـ Publishable key.',
    'الصقهم في التطبيق ودوس "حفظ واتصال"، وبعدين "عمل حساب جديد" بإيميلك.',
    'على الجهاز التاني: الصق "كود الربط" (هتلاقيه هنا بعد ما تدخل) وادخل بنفس الإيميل والباسورد.',
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'تجهيز المزامنة (مرة واحدة)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(steps[i])),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: supabaseSetupSql),
              );
              if (sheet.mounted) showSnack(sheet, 'اتنسخ كود الـ SQL ✓');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ كود الـ SQL'),
          ),
          const SizedBox(height: 8),
          Text(
            'المفتاح ده معمول عشان يتحط في التطبيقات، وكل حساب مش بيشوف غير '
            'بياناته بس. كله مجاني.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
