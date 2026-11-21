import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/sync/setup_sql.dart';
import 'package:study_planner/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('the SQL shown in the app matches supabase/setup.sql', () {
    final file = File('supabase/setup.sql').readAsStringSync();
    expect(
      supabaseSetupSql.replaceAll('\r\n', '\n').trim(),
      file.replaceAll('\r\n', '\n').trim(),
    );
  });

  test('the server guards against saves from old app versions', () {
    expect(supabaseSetupSql, contains('planner_state_guard'));
    expect(supabaseSetupSql, contains('before update on public.planner_state'));
  });

  test('the old-version message from the server is shown as is', () {
    const message = 'نسخة التطبيق دي قديمة — حدّثها عشان المزامنة تشتغل';
    expect(
      describeSyncError(
        const PostgrestException(message: message, code: 'P0001'),
      ),
      message,
    );
  });
}
