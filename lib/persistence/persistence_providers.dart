import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'plan_repository.dart';
import 'timeline_template_apply_service.dart';
import 'timeline_template_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main()');
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(databaseProvider));
});

final timelineTemplateRepositoryProvider = Provider<TimelineTemplateRepository>(
  (ref) {
    return TimelineTemplateRepository(ref.watch(databaseProvider));
  },
);

final timelineTemplateApplyServiceProvider =
    Provider<TimelineTemplateApplyService>((ref) {
      return TimelineTemplateApplyService(ref);
    });

class CurrentPlanIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String id) => state = id;

  void clear() => state = null;
}

final currentPlanIdProvider = NotifierProvider<CurrentPlanIdNotifier, String?>(
  CurrentPlanIdNotifier.new,
);
