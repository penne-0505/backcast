import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get targetTime => integer()();
  TextColumn get targetTimeTitle => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlanBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get planId =>
      text().references(Plans, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get title => text()();
  IntColumn get duration => integer()();
  IntColumn get colorIndex => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlanSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get planId =>
      text().references(Plans, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();
  TextColumn get stateJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TimelineTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get targetTime => integer()();
  TextColumn get targetTimeTitle => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TimelineTemplateBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(TimelineTemplates, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get title => text()();
  IntColumn get duration => integer()();
  IntColumn get colorIndex => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Plans, PlanBlocks, PlanSnapshots, TimelineTemplates, TimelineTemplateBlocks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'ato'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(timelineTemplates);
        await m.createTable(timelineTemplateBlocks);
      }
    },
  );
}
