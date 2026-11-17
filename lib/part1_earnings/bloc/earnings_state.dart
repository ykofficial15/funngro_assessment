part of 'earnings_bloc.dart';

sealed class EarningsState {
  const EarningsState();
}

/// First load, nothing to show yet.
final class EarningsLoading extends EarningsState {
  const EarningsLoading();
}

/// First load failed, nothing to show.
final class EarningsError extends EarningsState {
  const EarningsError(this.error);
  final Object error;
}

/// Data is on screen. `items` may be empty: the UI shows the empty state then.
final class EarningsLoaded extends EarningsState {
  const EarningsLoaded(
    this.items, {
    required this.totalInPaise,
    this.isRefreshing = false,
    this.refreshFailed = false,
  });

  final List<Earning> items; // newest first, unmodifiable

  /// Sum of `items`. Kept up to date by the bloc (full sum on load, +1
  /// amount per live update) so the UI never loops over 3,000 items in build.
  final int totalInPaise;
  final bool isRefreshing;

  /// One-shot flag: true only on the state emitted right after a failed
  /// refresh, so a BlocListener shows exactly one snackbar.
  final bool refreshFailed;

  /// `refreshFailed` isn't carried over: it resets unless passed explicitly.
  EarningsLoaded copyWith({
    List<Earning>? items,
    int? totalInPaise,
    bool? isRefreshing,
    bool refreshFailed = false,
  }) =>
      EarningsLoaded(
        items ?? this.items,
        totalInPaise: totalInPaise ?? this.totalInPaise,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        refreshFailed: refreshFailed,
      );
}
