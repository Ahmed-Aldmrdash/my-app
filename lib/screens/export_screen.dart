import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../services/image_export.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';

/// The weekly timetable or the finals timetable as a picture to share or
/// keep as a wallpaper.
class TimetableExportScreen extends StatefulWidget {
  const TimetableExportScreen({super.key, this.finals = false});

  final bool finals;

  @override
  State<TimetableExportScreen> createState() => _TimetableExportScreenState();
}

class _TimetableExportScreenState extends State<TimetableExportScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no image data');
      final message = await exportPng(
        data.buffer.asUint8List(),
        widget.finals ? 'finals.png' : 'timetable.png',
      );
      if (mounted && message != null) showSnack(context, message);
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) showSnack(context, 'مش قادر أطلّع الصورة — جرب تاني');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.finals ? 'صورة جدول الفاينال' : 'صورة الجدول'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'export-fab',
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share_rounded),
        label: const Text('شارك الصورة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Center(
          child: FittedBox(
            child: RepaintBoundary(
              key: _boundary,
              // Always light, whatever the app's theme: it's a picture.
              child: Theme(
                data: Theme.of(context).copyWith(
                  brightness: Brightness.light,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.primary,
                  ),
                ),
                child: SizedBox(
                  width: 420,
                  child: widget.finals
                      ? _FinalsSheet(store: store)
                      : _WeekSheet(store: store),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'منظم دراستي',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9A98B0), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.color,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(
              leading,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2B3A),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2B3A),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6880),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSheet extends StatelessWidget {
  const _WeekSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    // Saturday first, like the timetable screen.
    const days = [6, 7, 1, 2, 3, 4, 5];
    final name = store.settings.semesterName.trim();
    final children = <Widget>[];
    for (final d in days) {
      final sessions = store.sessionsOn(d);
      if (sessions.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(
            weekdayNames[d]!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
      for (final s in sessions) {
        final subject = store.subjectById(s.subjectId);
        children.add(
          _Row(
            color: subject == null
                ? AppColors.primary
                : Color(subject.colorValue),
            leading:
                '${formatMinuteOfDay(s.startMinute)}\n${formatMinuteOfDay(s.endMinute)}',
            title: '${s.type.label} ${subject?.name ?? ''}',
            subtitle: [
              if (s.location.isNotEmpty) s.location,
              if (s.instructor.isNotEmpty) s.instructor,
            ].join(' • '),
          ),
        );
      }
    }
    if (children.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('الجدول فاضي', textAlign: TextAlign.center),
        ),
      );
    }
    return _Sheet(
      title: name.isEmpty ? 'جدولي 📅' : 'جدولي — $name',
      children: children,
    );
  }
}

class _FinalsSheet extends StatelessWidget {
  const _FinalsSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final exams = store.upcomingFinals(DateTime.now());
    return _Sheet(
      title: 'جدول الفاينال 🎓',
      children: [
        if (exams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('مفيش امتحانات جاية', textAlign: TextAlign.center),
          ),
        for (final e in exams)
          _Row(
            color: store.subjectById(e.subjectId) == null
                ? AppColors.primary
                : Color(store.subjectById(e.subjectId)!.colorValue),
            leading: '${formatLongDate(e.start)}\n${formatTime(e.start)}',
            title: store.subjectById(e.subjectId)?.name ?? '',
            subtitle: [
              if (e.place.isNotEmpty) e.place,
              if (e.seat.isNotEmpty) 'رقم الجلوس ${ltr(e.seat)}',
            ].join(' • '),
          ),
      ],
    );
  }
}
