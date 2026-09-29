import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'data/storage.dart';
import 'services/notification_service.dart';
import 'sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final store = AppStore(createDefaultStorage());
  await store.load();

  final notifications = NotificationService.instance;
  await notifications.init();
  // Any change to the data re-plans the reminders.
  store.addListener(() => notifications.scheduleSoon(store));
  unawaited(notifications.rescheduleAll(store));

  final sync = SyncService(store);
  runApp(StudyPlannerApp(store: store, sync: sync));
  // Connects in the background; the app works offline meanwhile.
  unawaited(sync.init());
}
