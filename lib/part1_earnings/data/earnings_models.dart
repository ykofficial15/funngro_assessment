import 'package:flutter/foundation.dart';

/// Immutable. The original code mutated `e.detail` on a model shared with the
/// list — that state was lost on the next refetch anyway and made the list
/// rebuild for data it never displayed. Detail now lives on the detail screen.
@immutable
class Earning {
  const Earning({
    required this.id,
    required this.title,
    required this.amountInPaise,
    required this.earnedAt,
  });

  final String id;
  final String title;

  /// Assumption: money is stored as integer minor units (paise), never double.
  final int amountInPaise;
  final DateTime earnedAt;
}

@immutable
class EarningDetail {
  const EarningDetail({
    required this.id,
    required this.projectName,
    required this.companyName,
    required this.status,
  });

  final String id;
  final String projectName;
  final String companyName;
  final String status;
}
