// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlansTable extends Plans with TableInfo<$PlansTable, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTimeMeta = const VerificationMeta(
    'targetTime',
  );
  @override
  late final GeneratedColumn<int> targetTime = GeneratedColumn<int>(
    'target_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTimeTitleMeta = const VerificationMeta(
    'targetTimeTitle',
  );
  @override
  late final GeneratedColumn<String> targetTimeTitle = GeneratedColumn<String>(
    'target_time_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    targetTime,
    targetTimeTitle,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target_time')) {
      context.handle(
        _targetTimeMeta,
        targetTime.isAcceptableOrUnknown(data['target_time']!, _targetTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTimeMeta);
    }
    if (data.containsKey('target_time_title')) {
      context.handle(
        _targetTimeTitleMeta,
        targetTimeTitle.isAcceptableOrUnknown(
          data['target_time_title']!,
          _targetTimeTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTimeTitleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      targetTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_time'],
      )!,
      targetTimeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_time_title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlansTable createAlias(String alias) {
    return $PlansTable(attachedDatabase, alias);
  }
}

class Plan extends DataClass implements Insertable<Plan> {
  final String id;
  final String title;
  final int targetTime;
  final String targetTimeTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Plan({
    required this.id,
    required this.title,
    required this.targetTime,
    required this.targetTimeTitle,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['target_time'] = Variable<int>(targetTime);
    map['target_time_title'] = Variable<String>(targetTimeTitle);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      id: Value(id),
      title: Value(title),
      targetTime: Value(targetTime),
      targetTimeTitle: Value(targetTimeTitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Plan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      targetTime: serializer.fromJson<int>(json['targetTime']),
      targetTimeTitle: serializer.fromJson<String>(json['targetTimeTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'targetTime': serializer.toJson<int>(targetTime),
      'targetTimeTitle': serializer.toJson<String>(targetTimeTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Plan copyWith({
    String? id,
    String? title,
    int? targetTime,
    String? targetTimeTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Plan(
    id: id ?? this.id,
    title: title ?? this.title,
    targetTime: targetTime ?? this.targetTime,
    targetTimeTitle: targetTimeTitle ?? this.targetTimeTitle,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      targetTime: data.targetTime.present
          ? data.targetTime.value
          : this.targetTime,
      targetTimeTitle: data.targetTimeTitle.present
          ? data.targetTimeTitle.value
          : this.targetTimeTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetTime: $targetTime, ')
          ..write('targetTimeTitle: $targetTimeTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, targetTime, targetTimeTitle, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          other.id == this.id &&
          other.title == this.title &&
          other.targetTime == this.targetTime &&
          other.targetTimeTitle == this.targetTimeTitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> targetTime;
  final Value<String> targetTimeTitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlansCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.targetTime = const Value.absent(),
    this.targetTimeTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required String id,
    required String title,
    required int targetTime,
    required String targetTimeTitle,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       targetTime = Value(targetTime),
       targetTimeTitle = Value(targetTimeTitle),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Plan> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? targetTime,
    Expression<String>? targetTimeTitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (targetTime != null) 'target_time': targetTime,
      if (targetTimeTitle != null) 'target_time_title': targetTimeTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? targetTime,
    Value<String>? targetTimeTitle,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlansCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      targetTime: targetTime ?? this.targetTime,
      targetTimeTitle: targetTimeTitle ?? this.targetTimeTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (targetTime.present) {
      map['target_time'] = Variable<int>(targetTime.value);
    }
    if (targetTimeTitle.present) {
      map['target_time_title'] = Variable<String>(targetTimeTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetTime: $targetTime, ')
          ..write('targetTimeTitle: $targetTimeTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanBlocksTable extends PlanBlocks
    with TableInfo<$PlanBlocksTable, PlanBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bufferMinutesMeta = const VerificationMeta(
    'bufferMinutes',
  );
  @override
  late final GeneratedColumn<int> bufferMinutes = GeneratedColumn<int>(
    'buffer_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    type,
    title,
    duration,
    bufferMinutes,
    colorIndex,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('buffer_minutes')) {
      context.handle(
        _bufferMinutesMeta,
        bufferMinutes.isAcceptableOrUnknown(
          data['buffer_minutes']!,
          _bufferMinutesMeta,
        ),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      bufferMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_minutes'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlanBlocksTable createAlias(String alias) {
    return $PlanBlocksTable(attachedDatabase, alias);
  }
}

class PlanBlock extends DataClass implements Insertable<PlanBlock> {
  final String id;
  final String planId;
  final String type;
  final String title;
  final int duration;
  final int bufferMinutes;
  final int colorIndex;
  final int position;
  const PlanBlock({
    required this.id,
    required this.planId,
    required this.type,
    required this.title,
    required this.duration,
    required this.bufferMinutes,
    required this.colorIndex,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['duration'] = Variable<int>(duration);
    map['buffer_minutes'] = Variable<int>(bufferMinutes);
    map['color_index'] = Variable<int>(colorIndex);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlanBlocksCompanion toCompanion(bool nullToAbsent) {
    return PlanBlocksCompanion(
      id: Value(id),
      planId: Value(planId),
      type: Value(type),
      title: Value(title),
      duration: Value(duration),
      bufferMinutes: Value(bufferMinutes),
      colorIndex: Value(colorIndex),
      position: Value(position),
    );
  }

  factory PlanBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanBlock(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      duration: serializer.fromJson<int>(json['duration']),
      bufferMinutes: serializer.fromJson<int>(json['bufferMinutes']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'duration': serializer.toJson<int>(duration),
      'bufferMinutes': serializer.toJson<int>(bufferMinutes),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'position': serializer.toJson<int>(position),
    };
  }

  PlanBlock copyWith({
    String? id,
    String? planId,
    String? type,
    String? title,
    int? duration,
    int? bufferMinutes,
    int? colorIndex,
    int? position,
  }) => PlanBlock(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    type: type ?? this.type,
    title: title ?? this.title,
    duration: duration ?? this.duration,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    colorIndex: colorIndex ?? this.colorIndex,
    position: position ?? this.position,
  );
  PlanBlock copyWithCompanion(PlanBlocksCompanion data) {
    return PlanBlock(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      duration: data.duration.present ? data.duration.value : this.duration,
      bufferMinutes: data.bufferMinutes.present
          ? data.bufferMinutes.value
          : this.bufferMinutes,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanBlock(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('duration: $duration, ')
          ..write('bufferMinutes: $bufferMinutes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    type,
    title,
    duration,
    bufferMinutes,
    colorIndex,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanBlock &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.type == this.type &&
          other.title == this.title &&
          other.duration == this.duration &&
          other.bufferMinutes == this.bufferMinutes &&
          other.colorIndex == this.colorIndex &&
          other.position == this.position);
}

class PlanBlocksCompanion extends UpdateCompanion<PlanBlock> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> type;
  final Value<String> title;
  final Value<int> duration;
  final Value<int> bufferMinutes;
  final Value<int> colorIndex;
  final Value<int> position;
  final Value<int> rowid;
  const PlanBlocksCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.duration = const Value.absent(),
    this.bufferMinutes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanBlocksCompanion.insert({
    required String id,
    required String planId,
    required String type,
    required String title,
    required int duration,
    this.bufferMinutes = const Value.absent(),
    required int colorIndex,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       type = Value(type),
       title = Value(title),
       duration = Value(duration),
       colorIndex = Value(colorIndex),
       position = Value(position);
  static Insertable<PlanBlock> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<int>? duration,
    Expression<int>? bufferMinutes,
    Expression<int>? colorIndex,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (duration != null) 'duration': duration,
      if (bufferMinutes != null) 'buffer_minutes': bufferMinutes,
      if (colorIndex != null) 'color_index': colorIndex,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? type,
    Value<String>? title,
    Value<int>? duration,
    Value<int>? bufferMinutes,
    Value<int>? colorIndex,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlanBlocksCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      type: type ?? this.type,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      colorIndex: colorIndex ?? this.colorIndex,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (bufferMinutes.present) {
      map['buffer_minutes'] = Variable<int>(bufferMinutes.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanBlocksCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('duration: $duration, ')
          ..write('bufferMinutes: $bufferMinutes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanSnapshotsTable extends PlanSnapshots
    with TableInfo<$PlanSnapshotsTable, PlanSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  @override
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    label,
    stateJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stateJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlanSnapshotsTable createAlias(String alias) {
    return $PlanSnapshotsTable(attachedDatabase, alias);
  }
}

class PlanSnapshot extends DataClass implements Insertable<PlanSnapshot> {
  final String id;
  final String planId;
  final String? label;
  final String stateJson;
  final DateTime createdAt;
  const PlanSnapshot({
    required this.id,
    required this.planId,
    this.label,
    required this.stateJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['state_json'] = Variable<String>(stateJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlanSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return PlanSnapshotsCompanion(
      id: Value(id),
      planId: Value(planId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      stateJson: Value(stateJson),
      createdAt: Value(createdAt),
    );
  }

  factory PlanSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanSnapshot(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      label: serializer.fromJson<String?>(json['label']),
      stateJson: serializer.fromJson<String>(json['stateJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'label': serializer.toJson<String?>(label),
      'stateJson': serializer.toJson<String>(stateJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlanSnapshot copyWith({
    String? id,
    String? planId,
    Value<String?> label = const Value.absent(),
    String? stateJson,
    DateTime? createdAt,
  }) => PlanSnapshot(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    label: label.present ? label.value : this.label,
    stateJson: stateJson ?? this.stateJson,
    createdAt: createdAt ?? this.createdAt,
  );
  PlanSnapshot copyWithCompanion(PlanSnapshotsCompanion data) {
    return PlanSnapshot(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      label: data.label.present ? data.label.value : this.label,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanSnapshot(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('label: $label, ')
          ..write('stateJson: $stateJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, label, stateJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanSnapshot &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.label == this.label &&
          other.stateJson == this.stateJson &&
          other.createdAt == this.createdAt);
}

class PlanSnapshotsCompanion extends UpdateCompanion<PlanSnapshot> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String?> label;
  final Value<String> stateJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlanSnapshotsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.label = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanSnapshotsCompanion.insert({
    required String id,
    required String planId,
    this.label = const Value.absent(),
    required String stateJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       stateJson = Value(stateJson),
       createdAt = Value(createdAt);
  static Insertable<PlanSnapshot> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? label,
    Expression<String>? stateJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (label != null) 'label': label,
      if (stateJson != null) 'state_json': stateJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String?>? label,
    Value<String>? stateJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlanSnapshotsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      label: label ?? this.label,
      stateJson: stateJson ?? this.stateJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('label: $label, ')
          ..write('stateJson: $stateJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimelineTemplatesTable extends TimelineTemplates
    with TableInfo<$TimelineTemplatesTable, TimelineTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimelineTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTimeMeta = const VerificationMeta(
    'targetTime',
  );
  @override
  late final GeneratedColumn<int> targetTime = GeneratedColumn<int>(
    'target_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTimeTitleMeta = const VerificationMeta(
    'targetTimeTitle',
  );
  @override
  late final GeneratedColumn<String> targetTimeTitle = GeneratedColumn<String>(
    'target_time_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    targetTime,
    targetTimeTitle,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timeline_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimelineTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target_time')) {
      context.handle(
        _targetTimeMeta,
        targetTime.isAcceptableOrUnknown(data['target_time']!, _targetTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTimeMeta);
    }
    if (data.containsKey('target_time_title')) {
      context.handle(
        _targetTimeTitleMeta,
        targetTimeTitle.isAcceptableOrUnknown(
          data['target_time_title']!,
          _targetTimeTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTimeTitleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimelineTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimelineTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      targetTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_time'],
      )!,
      targetTimeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_time_title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TimelineTemplatesTable createAlias(String alias) {
    return $TimelineTemplatesTable(attachedDatabase, alias);
  }
}

class TimelineTemplate extends DataClass
    implements Insertable<TimelineTemplate> {
  final String id;
  final String title;
  final int targetTime;
  final String targetTimeTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TimelineTemplate({
    required this.id,
    required this.title,
    required this.targetTime,
    required this.targetTimeTitle,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['target_time'] = Variable<int>(targetTime);
    map['target_time_title'] = Variable<String>(targetTimeTitle);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TimelineTemplatesCompanion toCompanion(bool nullToAbsent) {
    return TimelineTemplatesCompanion(
      id: Value(id),
      title: Value(title),
      targetTime: Value(targetTime),
      targetTimeTitle: Value(targetTimeTitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TimelineTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimelineTemplate(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      targetTime: serializer.fromJson<int>(json['targetTime']),
      targetTimeTitle: serializer.fromJson<String>(json['targetTimeTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'targetTime': serializer.toJson<int>(targetTime),
      'targetTimeTitle': serializer.toJson<String>(targetTimeTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TimelineTemplate copyWith({
    String? id,
    String? title,
    int? targetTime,
    String? targetTimeTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TimelineTemplate(
    id: id ?? this.id,
    title: title ?? this.title,
    targetTime: targetTime ?? this.targetTime,
    targetTimeTitle: targetTimeTitle ?? this.targetTimeTitle,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TimelineTemplate copyWithCompanion(TimelineTemplatesCompanion data) {
    return TimelineTemplate(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      targetTime: data.targetTime.present
          ? data.targetTime.value
          : this.targetTime,
      targetTimeTitle: data.targetTimeTitle.present
          ? data.targetTimeTitle.value
          : this.targetTimeTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimelineTemplate(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetTime: $targetTime, ')
          ..write('targetTimeTitle: $targetTimeTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, targetTime, targetTimeTitle, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimelineTemplate &&
          other.id == this.id &&
          other.title == this.title &&
          other.targetTime == this.targetTime &&
          other.targetTimeTitle == this.targetTimeTitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TimelineTemplatesCompanion extends UpdateCompanion<TimelineTemplate> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> targetTime;
  final Value<String> targetTimeTitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TimelineTemplatesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.targetTime = const Value.absent(),
    this.targetTimeTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimelineTemplatesCompanion.insert({
    required String id,
    required String title,
    required int targetTime,
    required String targetTimeTitle,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       targetTime = Value(targetTime),
       targetTimeTitle = Value(targetTimeTitle),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TimelineTemplate> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? targetTime,
    Expression<String>? targetTimeTitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (targetTime != null) 'target_time': targetTime,
      if (targetTimeTitle != null) 'target_time_title': targetTimeTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimelineTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? targetTime,
    Value<String>? targetTimeTitle,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TimelineTemplatesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      targetTime: targetTime ?? this.targetTime,
      targetTimeTitle: targetTimeTitle ?? this.targetTimeTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (targetTime.present) {
      map['target_time'] = Variable<int>(targetTime.value);
    }
    if (targetTimeTitle.present) {
      map['target_time_title'] = Variable<String>(targetTimeTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimelineTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetTime: $targetTime, ')
          ..write('targetTimeTitle: $targetTimeTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimelineTemplateBlocksTable extends TimelineTemplateBlocks
    with TableInfo<$TimelineTemplateBlocksTable, TimelineTemplateBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimelineTemplateBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES timeline_templates (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bufferMinutesMeta = const VerificationMeta(
    'bufferMinutes',
  );
  @override
  late final GeneratedColumn<int> bufferMinutes = GeneratedColumn<int>(
    'buffer_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    type,
    title,
    duration,
    bufferMinutes,
    colorIndex,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timeline_template_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimelineTemplateBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('buffer_minutes')) {
      context.handle(
        _bufferMinutesMeta,
        bufferMinutes.isAcceptableOrUnknown(
          data['buffer_minutes']!,
          _bufferMinutesMeta,
        ),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimelineTemplateBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimelineTemplateBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      bufferMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_minutes'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $TimelineTemplateBlocksTable createAlias(String alias) {
    return $TimelineTemplateBlocksTable(attachedDatabase, alias);
  }
}

class TimelineTemplateBlock extends DataClass
    implements Insertable<TimelineTemplateBlock> {
  final String id;
  final String templateId;
  final String type;
  final String title;
  final int duration;
  final int bufferMinutes;
  final int colorIndex;
  final int position;
  const TimelineTemplateBlock({
    required this.id,
    required this.templateId,
    required this.type,
    required this.title,
    required this.duration,
    required this.bufferMinutes,
    required this.colorIndex,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['template_id'] = Variable<String>(templateId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['duration'] = Variable<int>(duration);
    map['buffer_minutes'] = Variable<int>(bufferMinutes);
    map['color_index'] = Variable<int>(colorIndex);
    map['position'] = Variable<int>(position);
    return map;
  }

  TimelineTemplateBlocksCompanion toCompanion(bool nullToAbsent) {
    return TimelineTemplateBlocksCompanion(
      id: Value(id),
      templateId: Value(templateId),
      type: Value(type),
      title: Value(title),
      duration: Value(duration),
      bufferMinutes: Value(bufferMinutes),
      colorIndex: Value(colorIndex),
      position: Value(position),
    );
  }

  factory TimelineTemplateBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimelineTemplateBlock(
      id: serializer.fromJson<String>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      duration: serializer.fromJson<int>(json['duration']),
      bufferMinutes: serializer.fromJson<int>(json['bufferMinutes']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateId': serializer.toJson<String>(templateId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'duration': serializer.toJson<int>(duration),
      'bufferMinutes': serializer.toJson<int>(bufferMinutes),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'position': serializer.toJson<int>(position),
    };
  }

  TimelineTemplateBlock copyWith({
    String? id,
    String? templateId,
    String? type,
    String? title,
    int? duration,
    int? bufferMinutes,
    int? colorIndex,
    int? position,
  }) => TimelineTemplateBlock(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    type: type ?? this.type,
    title: title ?? this.title,
    duration: duration ?? this.duration,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    colorIndex: colorIndex ?? this.colorIndex,
    position: position ?? this.position,
  );
  TimelineTemplateBlock copyWithCompanion(
    TimelineTemplateBlocksCompanion data,
  ) {
    return TimelineTemplateBlock(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      duration: data.duration.present ? data.duration.value : this.duration,
      bufferMinutes: data.bufferMinutes.present
          ? data.bufferMinutes.value
          : this.bufferMinutes,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimelineTemplateBlock(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('duration: $duration, ')
          ..write('bufferMinutes: $bufferMinutes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    type,
    title,
    duration,
    bufferMinutes,
    colorIndex,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimelineTemplateBlock &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.type == this.type &&
          other.title == this.title &&
          other.duration == this.duration &&
          other.bufferMinutes == this.bufferMinutes &&
          other.colorIndex == this.colorIndex &&
          other.position == this.position);
}

class TimelineTemplateBlocksCompanion
    extends UpdateCompanion<TimelineTemplateBlock> {
  final Value<String> id;
  final Value<String> templateId;
  final Value<String> type;
  final Value<String> title;
  final Value<int> duration;
  final Value<int> bufferMinutes;
  final Value<int> colorIndex;
  final Value<int> position;
  final Value<int> rowid;
  const TimelineTemplateBlocksCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.duration = const Value.absent(),
    this.bufferMinutes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimelineTemplateBlocksCompanion.insert({
    required String id,
    required String templateId,
    required String type,
    required String title,
    required int duration,
    this.bufferMinutes = const Value.absent(),
    required int colorIndex,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       templateId = Value(templateId),
       type = Value(type),
       title = Value(title),
       duration = Value(duration),
       colorIndex = Value(colorIndex),
       position = Value(position);
  static Insertable<TimelineTemplateBlock> custom({
    Expression<String>? id,
    Expression<String>? templateId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<int>? duration,
    Expression<int>? bufferMinutes,
    Expression<int>? colorIndex,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (duration != null) 'duration': duration,
      if (bufferMinutes != null) 'buffer_minutes': bufferMinutes,
      if (colorIndex != null) 'color_index': colorIndex,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimelineTemplateBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? templateId,
    Value<String>? type,
    Value<String>? title,
    Value<int>? duration,
    Value<int>? bufferMinutes,
    Value<int>? colorIndex,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return TimelineTemplateBlocksCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      type: type ?? this.type,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      colorIndex: colorIndex ?? this.colorIndex,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (bufferMinutes.present) {
      map['buffer_minutes'] = Variable<int>(bufferMinutes.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimelineTemplateBlocksCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('duration: $duration, ')
          ..write('bufferMinutes: $bufferMinutes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppPreference({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppPreference copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppPreference(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedProEntitlementsTable extends CachedProEntitlements
    with TableInfo<$CachedProEntitlementsTable, CachedProEntitlement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProEntitlementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isProMeta = const VerificationMeta('isPro');
  @override
  late final GeneratedColumn<bool> isPro = GeneratedColumn<bool>(
    'is_pro',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pro" IN (0, 1))',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    isPro,
    status,
    productId,
    expiresAt,
    lastSyncedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_pro_entitlements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProEntitlement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('is_pro')) {
      context.handle(
        _isProMeta,
        isPro.isAcceptableOrUnknown(data['is_pro']!, _isProMeta),
      );
    } else if (isInserting) {
      context.missing(_isProMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CachedProEntitlement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProEntitlement(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      isPro: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pro'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedProEntitlementsTable createAlias(String alias) {
    return $CachedProEntitlementsTable(attachedDatabase, alias);
  }
}

class CachedProEntitlement extends DataClass
    implements Insertable<CachedProEntitlement> {
  final String userId;
  final bool isPro;
  final String status;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime? lastSyncedAt;
  final DateTime cachedAt;
  const CachedProEntitlement({
    required this.userId,
    required this.isPro,
    required this.status,
    this.productId,
    this.expiresAt,
    this.lastSyncedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['is_pro'] = Variable<bool>(isPro);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedProEntitlementsCompanion toCompanion(bool nullToAbsent) {
    return CachedProEntitlementsCompanion(
      userId: Value(userId),
      isPro: Value(isPro),
      status: Value(status),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedProEntitlement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProEntitlement(
      userId: serializer.fromJson<String>(json['userId']),
      isPro: serializer.fromJson<bool>(json['isPro']),
      status: serializer.fromJson<String>(json['status']),
      productId: serializer.fromJson<String?>(json['productId']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'isPro': serializer.toJson<bool>(isPro),
      'status': serializer.toJson<String>(status),
      'productId': serializer.toJson<String?>(productId),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedProEntitlement copyWith({
    String? userId,
    bool? isPro,
    String? status,
    Value<String?> productId = const Value.absent(),
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedProEntitlement(
    userId: userId ?? this.userId,
    isPro: isPro ?? this.isPro,
    status: status ?? this.status,
    productId: productId.present ? productId.value : this.productId,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedProEntitlement copyWithCompanion(CachedProEntitlementsCompanion data) {
    return CachedProEntitlement(
      userId: data.userId.present ? data.userId.value : this.userId,
      isPro: data.isPro.present ? data.isPro.value : this.isPro,
      status: data.status.present ? data.status.value : this.status,
      productId: data.productId.present ? data.productId.value : this.productId,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProEntitlement(')
          ..write('userId: $userId, ')
          ..write('isPro: $isPro, ')
          ..write('status: $status, ')
          ..write('productId: $productId, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    isPro,
    status,
    productId,
    expiresAt,
    lastSyncedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProEntitlement &&
          other.userId == this.userId &&
          other.isPro == this.isPro &&
          other.status == this.status &&
          other.productId == this.productId &&
          other.expiresAt == this.expiresAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedProEntitlementsCompanion
    extends UpdateCompanion<CachedProEntitlement> {
  final Value<String> userId;
  final Value<bool> isPro;
  final Value<String> status;
  final Value<String?> productId;
  final Value<DateTime?> expiresAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedProEntitlementsCompanion({
    this.userId = const Value.absent(),
    this.isPro = const Value.absent(),
    this.status = const Value.absent(),
    this.productId = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProEntitlementsCompanion.insert({
    required String userId,
    required bool isPro,
    required String status,
    this.productId = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       isPro = Value(isPro),
       status = Value(status),
       cachedAt = Value(cachedAt);
  static Insertable<CachedProEntitlement> custom({
    Expression<String>? userId,
    Expression<bool>? isPro,
    Expression<String>? status,
    Expression<String>? productId,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (isPro != null) 'is_pro': isPro,
      if (status != null) 'status': status,
      if (productId != null) 'product_id': productId,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProEntitlementsCompanion copyWith({
    Value<String>? userId,
    Value<bool>? isPro,
    Value<String>? status,
    Value<String?>? productId,
    Value<DateTime?>? expiresAt,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedProEntitlementsCompanion(
      userId: userId ?? this.userId,
      isPro: isPro ?? this.isPro,
      status: status ?? this.status,
      productId: productId ?? this.productId,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (isPro.present) {
      map['is_pro'] = Variable<bool>(isPro.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProEntitlementsCompanion(')
          ..write('userId: $userId, ')
          ..write('isPro: $isPro, ')
          ..write('status: $status, ')
          ..write('productId: $productId, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalyticsEventsTable extends AnalyticsEvents
    with TableInfo<$AnalyticsEventsTable, AnalyticsEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalyticsEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventNameMeta = const VerificationMeta(
    'eventName',
  );
  @override
  late final GeneratedColumn<String> eventName = GeneratedColumn<String>(
    'event_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _propertiesJsonMeta = const VerificationMeta(
    'propertiesJson',
  );
  @override
  late final GeneratedColumn<String> propertiesJson = GeneratedColumn<String>(
    'properties_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _installIdMeta = const VerificationMeta(
    'installId',
  );
  @override
  late final GeneratedColumn<String> installId = GeneratedColumn<String>(
    'install_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventName,
    propertiesJson,
    occurredAt,
    sessionId,
    installId,
    uploadState,
    attemptCount,
    lastAttemptAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analytics_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalyticsEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_name')) {
      context.handle(
        _eventNameMeta,
        eventName.isAcceptableOrUnknown(data['event_name']!, _eventNameMeta),
      );
    } else if (isInserting) {
      context.missing(_eventNameMeta);
    }
    if (data.containsKey('properties_json')) {
      context.handle(
        _propertiesJsonMeta,
        propertiesJson.isAcceptableOrUnknown(
          data['properties_json']!,
          _propertiesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_propertiesJsonMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('install_id')) {
      context.handle(
        _installIdMeta,
        installId.isAcceptableOrUnknown(data['install_id']!, _installIdMeta),
      );
    } else if (isInserting) {
      context.missing(_installIdMeta);
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_uploadStateMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalyticsEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalyticsEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_name'],
      )!,
      propertiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties_json'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      installId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_id'],
      )!,
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AnalyticsEventsTable createAlias(String alias) {
    return $AnalyticsEventsTable(attachedDatabase, alias);
  }
}

class AnalyticsEvent extends DataClass implements Insertable<AnalyticsEvent> {
  final String id;
  final String eventName;
  final String propertiesJson;
  final DateTime occurredAt;
  final String sessionId;
  final String installId;
  final String uploadState;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  const AnalyticsEvent({
    required this.id,
    required this.eventName,
    required this.propertiesJson,
    required this.occurredAt,
    required this.sessionId,
    required this.installId,
    required this.uploadState,
    required this.attemptCount,
    this.lastAttemptAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_name'] = Variable<String>(eventName);
    map['properties_json'] = Variable<String>(propertiesJson);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['session_id'] = Variable<String>(sessionId);
    map['install_id'] = Variable<String>(installId);
    map['upload_state'] = Variable<String>(uploadState);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnalyticsEventsCompanion toCompanion(bool nullToAbsent) {
    return AnalyticsEventsCompanion(
      id: Value(id),
      eventName: Value(eventName),
      propertiesJson: Value(propertiesJson),
      occurredAt: Value(occurredAt),
      sessionId: Value(sessionId),
      installId: Value(installId),
      uploadState: Value(uploadState),
      attemptCount: Value(attemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      createdAt: Value(createdAt),
    );
  }

  factory AnalyticsEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalyticsEvent(
      id: serializer.fromJson<String>(json['id']),
      eventName: serializer.fromJson<String>(json['eventName']),
      propertiesJson: serializer.fromJson<String>(json['propertiesJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      installId: serializer.fromJson<String>(json['installId']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventName': serializer.toJson<String>(eventName),
      'propertiesJson': serializer.toJson<String>(propertiesJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'sessionId': serializer.toJson<String>(sessionId),
      'installId': serializer.toJson<String>(installId),
      'uploadState': serializer.toJson<String>(uploadState),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnalyticsEvent copyWith({
    String? id,
    String? eventName,
    String? propertiesJson,
    DateTime? occurredAt,
    String? sessionId,
    String? installId,
    String? uploadState,
    int? attemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? createdAt,
  }) => AnalyticsEvent(
    id: id ?? this.id,
    eventName: eventName ?? this.eventName,
    propertiesJson: propertiesJson ?? this.propertiesJson,
    occurredAt: occurredAt ?? this.occurredAt,
    sessionId: sessionId ?? this.sessionId,
    installId: installId ?? this.installId,
    uploadState: uploadState ?? this.uploadState,
    attemptCount: attemptCount ?? this.attemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    createdAt: createdAt ?? this.createdAt,
  );
  AnalyticsEvent copyWithCompanion(AnalyticsEventsCompanion data) {
    return AnalyticsEvent(
      id: data.id.present ? data.id.value : this.id,
      eventName: data.eventName.present ? data.eventName.value : this.eventName,
      propertiesJson: data.propertiesJson.present
          ? data.propertiesJson.value
          : this.propertiesJson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      installId: data.installId.present ? data.installId.value : this.installId,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsEvent(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('sessionId: $sessionId, ')
          ..write('installId: $installId, ')
          ..write('uploadState: $uploadState, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventName,
    propertiesJson,
    occurredAt,
    sessionId,
    installId,
    uploadState,
    attemptCount,
    lastAttemptAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalyticsEvent &&
          other.id == this.id &&
          other.eventName == this.eventName &&
          other.propertiesJson == this.propertiesJson &&
          other.occurredAt == this.occurredAt &&
          other.sessionId == this.sessionId &&
          other.installId == this.installId &&
          other.uploadState == this.uploadState &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.createdAt == this.createdAt);
}

class AnalyticsEventsCompanion extends UpdateCompanion<AnalyticsEvent> {
  final Value<String> id;
  final Value<String> eventName;
  final Value<String> propertiesJson;
  final Value<DateTime> occurredAt;
  final Value<String> sessionId;
  final Value<String> installId;
  final Value<String> uploadState;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AnalyticsEventsCompanion({
    this.id = const Value.absent(),
    this.eventName = const Value.absent(),
    this.propertiesJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.installId = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalyticsEventsCompanion.insert({
    required String id,
    required String eventName,
    required String propertiesJson,
    required DateTime occurredAt,
    required String sessionId,
    required String installId,
    required String uploadState,
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventName = Value(eventName),
       propertiesJson = Value(propertiesJson),
       occurredAt = Value(occurredAt),
       sessionId = Value(sessionId),
       installId = Value(installId),
       uploadState = Value(uploadState),
       createdAt = Value(createdAt);
  static Insertable<AnalyticsEvent> custom({
    Expression<String>? id,
    Expression<String>? eventName,
    Expression<String>? propertiesJson,
    Expression<DateTime>? occurredAt,
    Expression<String>? sessionId,
    Expression<String>? installId,
    Expression<String>? uploadState,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventName != null) 'event_name': eventName,
      if (propertiesJson != null) 'properties_json': propertiesJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (sessionId != null) 'session_id': sessionId,
      if (installId != null) 'install_id': installId,
      if (uploadState != null) 'upload_state': uploadState,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalyticsEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventName,
    Value<String>? propertiesJson,
    Value<DateTime>? occurredAt,
    Value<String>? sessionId,
    Value<String>? installId,
    Value<String>? uploadState,
    Value<int>? attemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AnalyticsEventsCompanion(
      id: id ?? this.id,
      eventName: eventName ?? this.eventName,
      propertiesJson: propertiesJson ?? this.propertiesJson,
      occurredAt: occurredAt ?? this.occurredAt,
      sessionId: sessionId ?? this.sessionId,
      installId: installId ?? this.installId,
      uploadState: uploadState ?? this.uploadState,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventName.present) {
      map['event_name'] = Variable<String>(eventName.value);
    }
    if (propertiesJson.present) {
      map['properties_json'] = Variable<String>(propertiesJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (installId.present) {
      map['install_id'] = Variable<String>(installId.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('sessionId: $sessionId, ')
          ..write('installId: $installId, ')
          ..write('uploadState: $uploadState, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlansTable plans = $PlansTable(this);
  late final $PlanBlocksTable planBlocks = $PlanBlocksTable(this);
  late final $PlanSnapshotsTable planSnapshots = $PlanSnapshotsTable(this);
  late final $TimelineTemplatesTable timelineTemplates =
      $TimelineTemplatesTable(this);
  late final $TimelineTemplateBlocksTable timelineTemplateBlocks =
      $TimelineTemplateBlocksTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $CachedProEntitlementsTable cachedProEntitlements =
      $CachedProEntitlementsTable(this);
  late final $AnalyticsEventsTable analyticsEvents = $AnalyticsEventsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    plans,
    planBlocks,
    planSnapshots,
    timelineTemplates,
    timelineTemplateBlocks,
    appPreferences,
    cachedProEntitlements,
    analyticsEvents,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('plan_blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('plan_snapshots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'timeline_templates',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('timeline_template_blocks', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$PlansTableCreateCompanionBuilder =
    PlansCompanion Function({
      required String id,
      required String title,
      required int targetTime,
      required String targetTimeTitle,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlansTableUpdateCompanionBuilder =
    PlansCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> targetTime,
      Value<String> targetTimeTitle,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlansTableReferences
    extends BaseReferences<_$AppDatabase, $PlansTable, Plan> {
  $$PlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlanBlocksTable, List<PlanBlock>>
  _planBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.planBlocks,
    aliasName: $_aliasNameGenerator(db.plans.id, db.planBlocks.planId),
  );

  $$PlanBlocksTableProcessedTableManager get planBlocksRefs {
    final manager = $$PlanBlocksTableTableManager(
      $_db,
      $_db.planBlocks,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlanSnapshotsTable, List<PlanSnapshot>>
  _planSnapshotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.planSnapshots,
    aliasName: $_aliasNameGenerator(db.plans.id, db.planSnapshots.planId),
  );

  $$PlanSnapshotsTableProcessedTableManager get planSnapshotsRefs {
    final manager = $$PlanSnapshotsTableTableManager(
      $_db,
      $_db.planSnapshots,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planSnapshotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlansTableFilterComposer extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> planBlocksRefs(
    Expression<bool> Function($$PlanBlocksTableFilterComposer f) f,
  ) {
    final $$PlanBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planBlocks,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanBlocksTableFilterComposer(
            $db: $db,
            $table: $db.planBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> planSnapshotsRefs(
    Expression<bool> Function($$PlanSnapshotsTableFilterComposer f) f,
  ) {
    final $$PlanSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planSnapshots,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.planSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> planBlocksRefs<T extends Object>(
    Expression<T> Function($$PlanBlocksTableAnnotationComposer a) f,
  ) {
    final $$PlanBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planBlocks,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.planBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> planSnapshotsRefs<T extends Object>(
    Expression<T> Function($$PlanSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$PlanSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planSnapshots,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.planSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlansTable,
          Plan,
          $$PlansTableFilterComposer,
          $$PlansTableOrderingComposer,
          $$PlansTableAnnotationComposer,
          $$PlansTableCreateCompanionBuilder,
          $$PlansTableUpdateCompanionBuilder,
          (Plan, $$PlansTableReferences),
          Plan,
          PrefetchHooks Function({bool planBlocksRefs, bool planSnapshotsRefs})
        > {
  $$PlansTableTableManager(_$AppDatabase db, $PlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> targetTime = const Value.absent(),
                Value<String> targetTimeTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion(
                id: id,
                title: title,
                targetTime: targetTime,
                targetTimeTitle: targetTimeTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int targetTime,
                required String targetTimeTitle,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion.insert(
                id: id,
                title: title,
                targetTime: targetTime,
                targetTimeTitle: targetTimeTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlansTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({planBlocksRefs = false, planSnapshotsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (planBlocksRefs) db.planBlocks,
                    if (planSnapshotsRefs) db.planSnapshots,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (planBlocksRefs)
                        await $_getPrefetchedData<Plan, $PlansTable, PlanBlock>(
                          currentTable: table,
                          referencedTable: $$PlansTableReferences
                              ._planBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlansTableReferences(
                                db,
                                table,
                                p0,
                              ).planBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (planSnapshotsRefs)
                        await $_getPrefetchedData<
                          Plan,
                          $PlansTable,
                          PlanSnapshot
                        >(
                          currentTable: table,
                          referencedTable: $$PlansTableReferences
                              ._planSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlansTableReferences(
                                db,
                                table,
                                p0,
                              ).planSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlansTable,
      Plan,
      $$PlansTableFilterComposer,
      $$PlansTableOrderingComposer,
      $$PlansTableAnnotationComposer,
      $$PlansTableCreateCompanionBuilder,
      $$PlansTableUpdateCompanionBuilder,
      (Plan, $$PlansTableReferences),
      Plan,
      PrefetchHooks Function({bool planBlocksRefs, bool planSnapshotsRefs})
    >;
typedef $$PlanBlocksTableCreateCompanionBuilder =
    PlanBlocksCompanion Function({
      required String id,
      required String planId,
      required String type,
      required String title,
      required int duration,
      Value<int> bufferMinutes,
      required int colorIndex,
      required int position,
      Value<int> rowid,
    });
typedef $$PlanBlocksTableUpdateCompanionBuilder =
    PlanBlocksCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> type,
      Value<String> title,
      Value<int> duration,
      Value<int> bufferMinutes,
      Value<int> colorIndex,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlanBlocksTableReferences
    extends BaseReferences<_$AppDatabase, $PlanBlocksTable, PlanBlock> {
  $$PlanBlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlansTable _planIdTable(_$AppDatabase db) => db.plans.createAlias(
    $_aliasNameGenerator(db.planBlocks.planId, db.plans.id),
  );

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlanBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanBlocksTable,
          PlanBlock,
          $$PlanBlocksTableFilterComposer,
          $$PlanBlocksTableOrderingComposer,
          $$PlanBlocksTableAnnotationComposer,
          $$PlanBlocksTableCreateCompanionBuilder,
          $$PlanBlocksTableUpdateCompanionBuilder,
          (PlanBlock, $$PlanBlocksTableReferences),
          PlanBlock,
          PrefetchHooks Function({bool planId})
        > {
  $$PlanBlocksTableTableManager(_$AppDatabase db, $PlanBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> bufferMinutes = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanBlocksCompanion(
                id: id,
                planId: planId,
                type: type,
                title: title,
                duration: duration,
                bufferMinutes: bufferMinutes,
                colorIndex: colorIndex,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String type,
                required String title,
                required int duration,
                Value<int> bufferMinutes = const Value.absent(),
                required int colorIndex,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlanBlocksCompanion.insert(
                id: id,
                planId: planId,
                type: type,
                title: title,
                duration: duration,
                bufferMinutes: bufferMinutes,
                colorIndex: colorIndex,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlanBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $$PlanBlocksTableReferences
                                    ._planIdTable(db),
                                referencedColumn: $$PlanBlocksTableReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlanBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanBlocksTable,
      PlanBlock,
      $$PlanBlocksTableFilterComposer,
      $$PlanBlocksTableOrderingComposer,
      $$PlanBlocksTableAnnotationComposer,
      $$PlanBlocksTableCreateCompanionBuilder,
      $$PlanBlocksTableUpdateCompanionBuilder,
      (PlanBlock, $$PlanBlocksTableReferences),
      PlanBlock,
      PrefetchHooks Function({bool planId})
    >;
typedef $$PlanSnapshotsTableCreateCompanionBuilder =
    PlanSnapshotsCompanion Function({
      required String id,
      required String planId,
      Value<String?> label,
      required String stateJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PlanSnapshotsTableUpdateCompanionBuilder =
    PlanSnapshotsCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String?> label,
      Value<String> stateJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PlanSnapshotsTableReferences
    extends BaseReferences<_$AppDatabase, $PlanSnapshotsTable, PlanSnapshot> {
  $$PlanSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlansTable _planIdTable(_$AppDatabase db) => db.plans.createAlias(
    $_aliasNameGenerator(db.planSnapshots.planId, db.plans.id),
  );

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlanSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanSnapshotsTable,
          PlanSnapshot,
          $$PlanSnapshotsTableFilterComposer,
          $$PlanSnapshotsTableOrderingComposer,
          $$PlanSnapshotsTableAnnotationComposer,
          $$PlanSnapshotsTableCreateCompanionBuilder,
          $$PlanSnapshotsTableUpdateCompanionBuilder,
          (PlanSnapshot, $$PlanSnapshotsTableReferences),
          PlanSnapshot,
          PrefetchHooks Function({bool planId})
        > {
  $$PlanSnapshotsTableTableManager(_$AppDatabase db, $PlanSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanSnapshotsCompanion(
                id: id,
                planId: planId,
                label: label,
                stateJson: stateJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                Value<String?> label = const Value.absent(),
                required String stateJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PlanSnapshotsCompanion.insert(
                id: id,
                planId: planId,
                label: label,
                stateJson: stateJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlanSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $$PlanSnapshotsTableReferences
                                    ._planIdTable(db),
                                referencedColumn: $$PlanSnapshotsTableReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlanSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanSnapshotsTable,
      PlanSnapshot,
      $$PlanSnapshotsTableFilterComposer,
      $$PlanSnapshotsTableOrderingComposer,
      $$PlanSnapshotsTableAnnotationComposer,
      $$PlanSnapshotsTableCreateCompanionBuilder,
      $$PlanSnapshotsTableUpdateCompanionBuilder,
      (PlanSnapshot, $$PlanSnapshotsTableReferences),
      PlanSnapshot,
      PrefetchHooks Function({bool planId})
    >;
typedef $$TimelineTemplatesTableCreateCompanionBuilder =
    TimelineTemplatesCompanion Function({
      required String id,
      required String title,
      required int targetTime,
      required String targetTimeTitle,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TimelineTemplatesTableUpdateCompanionBuilder =
    TimelineTemplatesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> targetTime,
      Value<String> targetTimeTitle,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TimelineTemplatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TimelineTemplatesTable,
          TimelineTemplate
        > {
  $$TimelineTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $TimelineTemplateBlocksTable,
    List<TimelineTemplateBlock>
  >
  _timelineTemplateBlocksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timelineTemplateBlocks,
        aliasName: $_aliasNameGenerator(
          db.timelineTemplates.id,
          db.timelineTemplateBlocks.templateId,
        ),
      );

  $$TimelineTemplateBlocksTableProcessedTableManager
  get timelineTemplateBlocksRefs {
    final manager = $$TimelineTemplateBlocksTableTableManager(
      $_db,
      $_db.timelineTemplateBlocks,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timelineTemplateBlocksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TimelineTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TimelineTemplatesTable> {
  $$TimelineTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> timelineTemplateBlocksRefs(
    Expression<bool> Function($$TimelineTemplateBlocksTableFilterComposer f) f,
  ) {
    final $$TimelineTemplateBlocksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.timelineTemplateBlocks,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TimelineTemplateBlocksTableFilterComposer(
                $db: $db,
                $table: $db.timelineTemplateBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TimelineTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TimelineTemplatesTable> {
  $$TimelineTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimelineTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimelineTemplatesTable> {
  $$TimelineTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get targetTime => $composableBuilder(
    column: $table.targetTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetTimeTitle => $composableBuilder(
    column: $table.targetTimeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> timelineTemplateBlocksRefs<T extends Object>(
    Expression<T> Function($$TimelineTemplateBlocksTableAnnotationComposer a) f,
  ) {
    final $$TimelineTemplateBlocksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.timelineTemplateBlocks,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TimelineTemplateBlocksTableAnnotationComposer(
                $db: $db,
                $table: $db.timelineTemplateBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TimelineTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimelineTemplatesTable,
          TimelineTemplate,
          $$TimelineTemplatesTableFilterComposer,
          $$TimelineTemplatesTableOrderingComposer,
          $$TimelineTemplatesTableAnnotationComposer,
          $$TimelineTemplatesTableCreateCompanionBuilder,
          $$TimelineTemplatesTableUpdateCompanionBuilder,
          (TimelineTemplate, $$TimelineTemplatesTableReferences),
          TimelineTemplate,
          PrefetchHooks Function({bool timelineTemplateBlocksRefs})
        > {
  $$TimelineTemplatesTableTableManager(
    _$AppDatabase db,
    $TimelineTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimelineTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimelineTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimelineTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> targetTime = const Value.absent(),
                Value<String> targetTimeTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineTemplatesCompanion(
                id: id,
                title: title,
                targetTime: targetTime,
                targetTimeTitle: targetTimeTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int targetTime,
                required String targetTimeTitle,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TimelineTemplatesCompanion.insert(
                id: id,
                title: title,
                targetTime: targetTime,
                targetTimeTitle: targetTimeTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimelineTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({timelineTemplateBlocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (timelineTemplateBlocksRefs) db.timelineTemplateBlocks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (timelineTemplateBlocksRefs)
                    await $_getPrefetchedData<
                      TimelineTemplate,
                      $TimelineTemplatesTable,
                      TimelineTemplateBlock
                    >(
                      currentTable: table,
                      referencedTable: $$TimelineTemplatesTableReferences
                          ._timelineTemplateBlocksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TimelineTemplatesTableReferences(
                            db,
                            table,
                            p0,
                          ).timelineTemplateBlocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.templateId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TimelineTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimelineTemplatesTable,
      TimelineTemplate,
      $$TimelineTemplatesTableFilterComposer,
      $$TimelineTemplatesTableOrderingComposer,
      $$TimelineTemplatesTableAnnotationComposer,
      $$TimelineTemplatesTableCreateCompanionBuilder,
      $$TimelineTemplatesTableUpdateCompanionBuilder,
      (TimelineTemplate, $$TimelineTemplatesTableReferences),
      TimelineTemplate,
      PrefetchHooks Function({bool timelineTemplateBlocksRefs})
    >;
typedef $$TimelineTemplateBlocksTableCreateCompanionBuilder =
    TimelineTemplateBlocksCompanion Function({
      required String id,
      required String templateId,
      required String type,
      required String title,
      required int duration,
      Value<int> bufferMinutes,
      required int colorIndex,
      required int position,
      Value<int> rowid,
    });
typedef $$TimelineTemplateBlocksTableUpdateCompanionBuilder =
    TimelineTemplateBlocksCompanion Function({
      Value<String> id,
      Value<String> templateId,
      Value<String> type,
      Value<String> title,
      Value<int> duration,
      Value<int> bufferMinutes,
      Value<int> colorIndex,
      Value<int> position,
      Value<int> rowid,
    });

final class $$TimelineTemplateBlocksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TimelineTemplateBlocksTable,
          TimelineTemplateBlock
        > {
  $$TimelineTemplateBlocksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TimelineTemplatesTable _templateIdTable(_$AppDatabase db) =>
      db.timelineTemplates.createAlias(
        $_aliasNameGenerator(
          db.timelineTemplateBlocks.templateId,
          db.timelineTemplates.id,
        ),
      );

  $$TimelineTemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<String>('template_id')!;

    final manager = $$TimelineTemplatesTableTableManager(
      $_db,
      $_db.timelineTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimelineTemplateBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $TimelineTemplateBlocksTable> {
  $$TimelineTemplateBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$TimelineTemplatesTableFilterComposer get templateId {
    final $$TimelineTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.timelineTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimelineTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.timelineTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimelineTemplateBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $TimelineTemplateBlocksTable> {
  $$TimelineTemplateBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$TimelineTemplatesTableOrderingComposer get templateId {
    final $$TimelineTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.timelineTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimelineTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.timelineTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimelineTemplateBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimelineTemplateBlocksTable> {
  $$TimelineTemplateBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get bufferMinutes => $composableBuilder(
    column: $table.bufferMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$TimelineTemplatesTableAnnotationComposer get templateId {
    final $$TimelineTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.timelineTemplates,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TimelineTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.timelineTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TimelineTemplateBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimelineTemplateBlocksTable,
          TimelineTemplateBlock,
          $$TimelineTemplateBlocksTableFilterComposer,
          $$TimelineTemplateBlocksTableOrderingComposer,
          $$TimelineTemplateBlocksTableAnnotationComposer,
          $$TimelineTemplateBlocksTableCreateCompanionBuilder,
          $$TimelineTemplateBlocksTableUpdateCompanionBuilder,
          (TimelineTemplateBlock, $$TimelineTemplateBlocksTableReferences),
          TimelineTemplateBlock,
          PrefetchHooks Function({bool templateId})
        > {
  $$TimelineTemplateBlocksTableTableManager(
    _$AppDatabase db,
    $TimelineTemplateBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimelineTemplateBlocksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TimelineTemplateBlocksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TimelineTemplateBlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> bufferMinutes = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineTemplateBlocksCompanion(
                id: id,
                templateId: templateId,
                type: type,
                title: title,
                duration: duration,
                bufferMinutes: bufferMinutes,
                colorIndex: colorIndex,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String templateId,
                required String type,
                required String title,
                required int duration,
                Value<int> bufferMinutes = const Value.absent(),
                required int colorIndex,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => TimelineTemplateBlocksCompanion.insert(
                id: id,
                templateId: templateId,
                type: type,
                title: title,
                duration: duration,
                bufferMinutes: bufferMinutes,
                colorIndex: colorIndex,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimelineTemplateBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable:
                                    $$TimelineTemplateBlocksTableReferences
                                        ._templateIdTable(db),
                                referencedColumn:
                                    $$TimelineTemplateBlocksTableReferences
                                        ._templateIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimelineTemplateBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimelineTemplateBlocksTable,
      TimelineTemplateBlock,
      $$TimelineTemplateBlocksTableFilterComposer,
      $$TimelineTemplateBlocksTableOrderingComposer,
      $$TimelineTemplateBlocksTableAnnotationComposer,
      $$TimelineTemplateBlocksTableCreateCompanionBuilder,
      $$TimelineTemplateBlocksTableUpdateCompanionBuilder,
      (TimelineTemplateBlock, $$TimelineTemplateBlocksTableReferences),
      TimelineTemplateBlock,
      PrefetchHooks Function({bool templateId})
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreference,
            BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
          ),
          AppPreference,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreference,
        BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
      ),
      AppPreference,
      PrefetchHooks Function()
    >;
typedef $$CachedProEntitlementsTableCreateCompanionBuilder =
    CachedProEntitlementsCompanion Function({
      required String userId,
      required bool isPro,
      required String status,
      Value<String?> productId,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSyncedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedProEntitlementsTableUpdateCompanionBuilder =
    CachedProEntitlementsCompanion Function({
      Value<String> userId,
      Value<bool> isPro,
      Value<String> status,
      Value<String?> productId,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedProEntitlementsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProEntitlementsTable> {
  $$CachedProEntitlementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPro => $composableBuilder(
    column: $table.isPro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProEntitlementsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProEntitlementsTable> {
  $$CachedProEntitlementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPro => $composableBuilder(
    column: $table.isPro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProEntitlementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProEntitlementsTable> {
  $$CachedProEntitlementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<bool> get isPro =>
      $composableBuilder(column: $table.isPro, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedProEntitlementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProEntitlementsTable,
          CachedProEntitlement,
          $$CachedProEntitlementsTableFilterComposer,
          $$CachedProEntitlementsTableOrderingComposer,
          $$CachedProEntitlementsTableAnnotationComposer,
          $$CachedProEntitlementsTableCreateCompanionBuilder,
          $$CachedProEntitlementsTableUpdateCompanionBuilder,
          (
            CachedProEntitlement,
            BaseReferences<
              _$AppDatabase,
              $CachedProEntitlementsTable,
              CachedProEntitlement
            >,
          ),
          CachedProEntitlement,
          PrefetchHooks Function()
        > {
  $$CachedProEntitlementsTableTableManager(
    _$AppDatabase db,
    $CachedProEntitlementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProEntitlementsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedProEntitlementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedProEntitlementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<bool> isPro = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProEntitlementsCompanion(
                userId: userId,
                isPro: isPro,
                status: status,
                productId: productId,
                expiresAt: expiresAt,
                lastSyncedAt: lastSyncedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required bool isPro,
                required String status,
                Value<String?> productId = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedProEntitlementsCompanion.insert(
                userId: userId,
                isPro: isPro,
                status: status,
                productId: productId,
                expiresAt: expiresAt,
                lastSyncedAt: lastSyncedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProEntitlementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProEntitlementsTable,
      CachedProEntitlement,
      $$CachedProEntitlementsTableFilterComposer,
      $$CachedProEntitlementsTableOrderingComposer,
      $$CachedProEntitlementsTableAnnotationComposer,
      $$CachedProEntitlementsTableCreateCompanionBuilder,
      $$CachedProEntitlementsTableUpdateCompanionBuilder,
      (
        CachedProEntitlement,
        BaseReferences<
          _$AppDatabase,
          $CachedProEntitlementsTable,
          CachedProEntitlement
        >,
      ),
      CachedProEntitlement,
      PrefetchHooks Function()
    >;
typedef $$AnalyticsEventsTableCreateCompanionBuilder =
    AnalyticsEventsCompanion Function({
      required String id,
      required String eventName,
      required String propertiesJson,
      required DateTime occurredAt,
      required String sessionId,
      required String installId,
      required String uploadState,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AnalyticsEventsTableUpdateCompanionBuilder =
    AnalyticsEventsCompanion Function({
      Value<String> id,
      Value<String> eventName,
      Value<String> propertiesJson,
      Value<DateTime> occurredAt,
      Value<String> sessionId,
      Value<String> installId,
      Value<String> uploadState,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AnalyticsEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalyticsEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalyticsEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventName =>
      $composableBuilder(column: $table.eventName, builder: (column) => column);

  GeneratedColumn<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get installId =>
      $composableBuilder(column: $table.installId, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AnalyticsEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalyticsEventsTable,
          AnalyticsEvent,
          $$AnalyticsEventsTableFilterComposer,
          $$AnalyticsEventsTableOrderingComposer,
          $$AnalyticsEventsTableAnnotationComposer,
          $$AnalyticsEventsTableCreateCompanionBuilder,
          $$AnalyticsEventsTableUpdateCompanionBuilder,
          (
            AnalyticsEvent,
            BaseReferences<
              _$AppDatabase,
              $AnalyticsEventsTable,
              AnalyticsEvent
            >,
          ),
          AnalyticsEvent,
          PrefetchHooks Function()
        > {
  $$AnalyticsEventsTableTableManager(
    _$AppDatabase db,
    $AnalyticsEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalyticsEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalyticsEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalyticsEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventName = const Value.absent(),
                Value<String> propertiesJson = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> installId = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsEventsCompanion(
                id: id,
                eventName: eventName,
                propertiesJson: propertiesJson,
                occurredAt: occurredAt,
                sessionId: sessionId,
                installId: installId,
                uploadState: uploadState,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventName,
                required String propertiesJson,
                required DateTime occurredAt,
                required String sessionId,
                required String installId,
                required String uploadState,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsEventsCompanion.insert(
                id: id,
                eventName: eventName,
                propertiesJson: propertiesJson,
                occurredAt: occurredAt,
                sessionId: sessionId,
                installId: installId,
                uploadState: uploadState,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalyticsEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalyticsEventsTable,
      AnalyticsEvent,
      $$AnalyticsEventsTableFilterComposer,
      $$AnalyticsEventsTableOrderingComposer,
      $$AnalyticsEventsTableAnnotationComposer,
      $$AnalyticsEventsTableCreateCompanionBuilder,
      $$AnalyticsEventsTableUpdateCompanionBuilder,
      (
        AnalyticsEvent,
        BaseReferences<_$AppDatabase, $AnalyticsEventsTable, AnalyticsEvent>,
      ),
      AnalyticsEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db, _db.plans);
  $$PlanBlocksTableTableManager get planBlocks =>
      $$PlanBlocksTableTableManager(_db, _db.planBlocks);
  $$PlanSnapshotsTableTableManager get planSnapshots =>
      $$PlanSnapshotsTableTableManager(_db, _db.planSnapshots);
  $$TimelineTemplatesTableTableManager get timelineTemplates =>
      $$TimelineTemplatesTableTableManager(_db, _db.timelineTemplates);
  $$TimelineTemplateBlocksTableTableManager get timelineTemplateBlocks =>
      $$TimelineTemplateBlocksTableTableManager(
        _db,
        _db.timelineTemplateBlocks,
      );
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$CachedProEntitlementsTableTableManager get cachedProEntitlements =>
      $$CachedProEntitlementsTableTableManager(_db, _db.cachedProEntitlements);
  $$AnalyticsEventsTableTableManager get analyticsEvents =>
      $$AnalyticsEventsTableTableManager(_db, _db.analyticsEvents);
}
