//
//  pushlog
//  day_summary.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:equatable/equatable.dart';

class DaySummary extends Equatable {
  const DaySummary({
    required this.date,
    required this.count,
    required this.isToday,
  });

  final DateTime date;
  final int count;
  final bool isToday;

  String get id {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  List<Object?> get props => [date, count, isToday];
}
