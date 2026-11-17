import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funngro_assessment/common/widgets.dart';
import 'package:funngro_assessment/part1_earnings/bloc/earnings_bloc.dart';
import 'package:funngro_assessment/part1_earnings/data/earnings_api.dart';
import 'package:funngro_assessment/part1_earnings/data/earnings_models.dart';
import 'package:funngro_assessment/part1_earnings/ui/earnings_screen.dart';

Earning earning(String id) =>
    Earning(id: id, title: id, amountInPaise: 100, earnedAt: DateTime(2026));

/// A live payout from the wallet stream.
Earning update(String id) => earning(id);

/// The test decides when each fetch resolves and when updates arrive.
class ControlledApi implements EarningsApi {
  final updates = StreamController<Earning>();
  Completer<List<Earning>> fetch = Completer();
  int fetchCount = 0;

  @override
  Future<List<Earning>> fetchEarnings(String userId) {
    fetchCount++;
    return (fetch = Completer()).future;
  }

  @override
  Stream<Earning> walletUpdates(String userId) => updates.stream;

  @override
  Future<EarningDetail> fetchDetail(String earningId) => throw UnimplementedError();
}

/// Lets every queued event and microtask run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

EarningsBloc startedBloc(ControlledApi service) =>
    EarningsBloc(api: service, userId: 'u')
      ..add(const EarningsStarted());

List<String> ids(EarningsBloc b) =>
    (b.state as EarningsLoaded).items.map((e) => e.id).toList();

void main() {
  test('update that arrives during the initial fetch is merged, not lost', () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    expect(bloc.state, isA<EarningsLoading>());

    service.updates.add(update('live1'));
    await settle();
    service.fetch.complete([earning('a'), earning('b')]);
    await settle();

    expect(ids(bloc), ['live1', 'a', 'b']);
    await bloc.close();
  });

  test('update that arrives while the error state is showing appears after retry',
      () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    service.fetch.completeError(Exception('net'));
    await settle();
    expect(bloc.state, isA<EarningsError>());

    service.updates.add(update('live1')); // no list on screen, no fetch in flight
    await settle();
    bloc.add(const EarningsLoadRequested());
    await settle();
    service.fetch.complete([earning('a')]);
    await settle();

    expect(ids(bloc), ['live1', 'a']);
    await bloc.close();
  });

  test('duplicate updates and updates already in the fetch are deduped', () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    service.updates.add(update('a')); // the server response also includes "a"
    await settle();
    service.fetch.complete([earning('a'), earning('b')]);
    await settle();

    service.updates
      ..add(update('c'))
      ..add(update('c'));
    await settle();

    expect(ids(bloc), ['c', 'a', 'b']);
    await bloc.close();
  });

  test('first-load error, retry, then a failed refresh keeps data', () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    service.fetch.completeError(Exception('net'));
    await settle();
    expect(bloc.state, isA<EarningsError>());

    bloc.add(const EarningsLoadRequested());
    await settle();
    service.fetch.complete([earning('a')]);
    await settle();
    expect(ids(bloc), ['a']);

    final done = Completer<void>();
    bloc.add(EarningsLoadRequested(onDone: done));
    await settle();
    expect((bloc.state as EarningsLoaded).isRefreshing, isTrue);
    service.fetch.completeError(Exception('net'));
    await done.future;

    final s = bloc.state as EarningsLoaded;
    expect(s.items.single.id, 'a');
    expect(s.refreshFailed, isTrue);
    expect(s.isRefreshing, isFalse);
    await bloc.close();
  });

  test('a newer load wins over an older, slower one (restartable)', () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    final first = service.fetch;

    bloc.add(const EarningsLoadRequested()); // supersedes the first
    await settle();
    final second = service.fetch;

    second.complete([earning('new')]);
    await settle();
    first.complete([earning('old')]); // late: must be ignored
    await settle();

    expect(ids(bloc), ['new']);
    await bloc.close();
  });

  test('close() cancels the wallet subscription', () async {
    final service = ControlledApi();
    final bloc = startedBloc(service);
    await settle();
    expect(service.updates.hasListener, isTrue);

    await bloc.close();
    expect(service.updates.hasListener, isFalse);
    service.fetch.complete([earning('a')]); // late result after close: no error
    await settle();
    expect(service.fetchCount, 1);
  });

  testWidgets('3,000 entries: only visible rows are built', (tester) async {
    final service = ControlledApi();
    await tester.pumpWidget(RepositoryProvider<EarningsApi>(
      create: (_) => service,
      child: const MaterialApp(home: EarningsPage(userId: 'u')),
    ));
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget); // first-load state

    service.fetch.complete(List.generate(3000, (i) => earning('e$i')));
    await tester.pumpAndSettle(); // state arrives via a stream, then a frame
    expect(find.text('e0'), findsOneWidget);
    expect(find.text('e2999'), findsNothing); // never built off-screen
    final built = find.byType(EarningTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(30));

    service.updates.add(update('live'));
    await tester.pumpAndSettle();
    expect(find.text('live'), findsOneWidget); // prepended at the top
  });
}
