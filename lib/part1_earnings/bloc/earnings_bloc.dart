import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/earnings_api.dart';
import '../data/earnings_models.dart';

part 'earnings_event.dart';
part 'earnings_state.dart';

/// Owns the earnings fetch and the wallet-updates subscription for one user.
/// Its lifetime is the BlocProvider's: created when the route is pushed and
/// closed (which cancels the subscription) when the route is removed.
class EarningsBloc extends Bloc<EarningsEvent, EarningsState> {
  EarningsBloc({required this.api, required this.userId})
      : super(const EarningsLoading()) {
    on<EarningsStarted>(_onStarted);
    // restartable(): a new load cancels the one in flight. Its emits become
    // no-ops, so an older, slower response can never overwrite a newer one.
    on<EarningsLoadRequested>(_onLoadRequested, transformer: restartable());
    on<_EarningReceived>(_onEarningReceived);
  }

  final EarningsApi api;
  final String userId;

  StreamSubscription<Earning>? _subscription;

  /// IDs currently in the list, used to drop duplicate updates.
  final Set<String> _ids = {};

  /// Live updates that the list on screen doesn't include yet: ones that
  /// arrived while a fetch was in flight, or while there was no list
  /// (loading/error). The next successful fetch replaces the list, so these
  /// are merged into it (deduped) or they'd be lost. Cleared only on success.
  final List<Earning> _pending = [];
  bool _fetchInFlight = false;

  void _onStarted(EarningsStarted event, Emitter<EarningsState> emit) {
    if (_subscription != null) return; // only once
    // Subscribe before fetching so no update is missed in between.
    _subscription = api.walletUpdates(userId).listen(
          (earning) => add(_EarningReceived(earning)),
          // A stream error shouldn't take down a screen that already has data.
          // In production: log to Crashlytics and resubscribe with backoff.
          onError: (Object e, StackTrace st) => debugPrint('walletUpdates: $e'),
        );
    add(const EarningsLoadRequested());
  }

  Future<void> _onLoadRequested(
    EarningsLoadRequested event,
    Emitter<EarningsState> emit,
  ) async {
    _fetchInFlight = true;

    final before = state;
    emit(before is EarningsLoaded
        ? before.copyWith(isRefreshing: true)
        : const EarningsLoading());

    try {
      final data = await api.fetchEarnings(userId);
      // Cancelled by a newer load (or the bloc closed): leave the shared
      // fields to the handler that replaced us.
      if (emit.isDone) return;

      // Newest live updates first, then server data, deduped by id.
      final merged = <Earning>[];
      final ids = <String>{};
      var total = 0;
      for (final e in [..._pending.reversed, ...data]) {
        if (ids.add(e.id)) {
          merged.add(e);
          total += e.amountInPaise;
        }
      }
      _ids
        ..clear()
        ..addAll(ids);
      _fetchInFlight = false;
      _pending.clear();
      emit(EarningsLoaded(List.unmodifiable(merged), totalInPaise: total));
    } catch (e) {
      if (emit.isDone) return;
      _fetchInFlight = false;
      final current = state;
      // A failed refresh keeps what's on screen. Only show the full-screen
      // error when there's nothing to show.
      emit(current is EarningsLoaded
          ? current.copyWith(isRefreshing: false, refreshFailed: true)
          : EarningsError(e));
    } finally {
      event.onDone?.complete();
    }
  }

  void _onEarningReceived(_EarningReceived event, Emitter<EarningsState> emit) {
    final earning = event.earning;
    final current = state;
    if (_fetchInFlight || current is! EarningsLoaded) _pending.add(earning);

    if (current is EarningsLoaded && _ids.add(earning.id)) {
      // New list rather than mutating in place: every state stays immutable.
      // Copying 3k references costs microseconds.
      emit(current.copyWith(
        items: List.unmodifiable([earning, ...current.items]),
        totalInPaise: current.totalInPaise + earning.amountInPaise,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel(); // before super.close(), so no add() after close
    return super.close();
  }
}
