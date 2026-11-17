import 'dart:async';
import 'dart:math';

import 'earnings_models.dart';

/// The data layer for earnings: the one thing the blocs talk to. It's an
/// interface, so tests and the demo can swap in a fake. In the real app the
/// implementation wraps HTTP + JSON decoding and returns domain models.
abstract interface class EarningsApi {
  Future<List<Earning>> fetchEarnings(String userId);

  /// Live payouts for [userId], as they happen.
  Stream<Earning> walletUpdates(String userId);

  Future<EarningDetail> fetchDetail(String earningId);
}

/// Demo implementation: 3,000 entries, a live payout every few seconds,
/// and calls that fail sometimes.
class FakeEarningsApi implements EarningsApi {
  FakeEarningsApi({this.entryCount = 3000});

  final int entryCount;
  final _rng = Random();

  static const _titles = [
    'Instagram reel for a café',
    'Logo design',
    'Blog article: study tips',
    'App testing feedback',
    'Survey data entry',
    'YouTube thumbnail set',
    'Product description copy',
  ];

  @override
  Future<List<Earning>> fetchEarnings(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_rng.nextInt(6) == 0) throw Exception('Network error');
    final now = DateTime.now();
    return List.generate(entryCount, (i) {
      return Earning(
        id: 'e$i',
        title: _titles[i % _titles.length],
        amountInPaise: (50 + _rng.nextInt(5000)) * 100,
        earnedAt: now.subtract(Duration(hours: 6 + i * 7)),
      );
    });
  }

  @override
  Stream<Earning> walletUpdates(String userId) {
    var n = 0;
    return Stream.periodic(const Duration(seconds: 6), (_) {
      n++;
      return Earning(
        id: 'live-$n',
        title: 'New payout (live #$n)',
        amountInPaise: (100 + _rng.nextInt(900)) * 100,
        earnedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<EarningDetail> fetchDetail(String earningId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_rng.nextInt(4) == 0) throw Exception('Could not load detail');
    return EarningDetail(
      id: earningId,
      projectName: 'Social media campaign',
      companyName: 'Company ${_rng.nextInt(50)}',
      status: 'Paid to wallet',
    );
  }
}
