part of 'earnings_bloc.dart';

sealed class EarningsEvent {
  const EarningsEvent();
}

/// Added once, when the bloc is created. Subscribes to live updates, then loads.
final class EarningsStarted extends EarningsEvent {
  const EarningsStarted();
}

/// Initial load, Retry, and pull-to-refresh. [onDone] completes when this
/// load ends, so RefreshIndicator can stop spinning.
final class EarningsLoadRequested extends EarningsEvent {
  const EarningsLoadRequested({this.onDone});
  final Completer<void>? onDone;
}

/// Internal: a live payout arrived from the wallet stream.
final class _EarningReceived extends EarningsEvent {
  const _EarningReceived(this.earning);
  final Earning earning;
}
