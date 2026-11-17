import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/earnings_models.dart';
import '../data/earnings_api.dart';

// Small enough to keep the events and states in the same file.

sealed class EarningDetailEvent {
  const EarningDetailEvent();
}

/// First load and Retry.
final class EarningDetailRequested extends EarningDetailEvent {
  const EarningDetailRequested();
}

sealed class EarningDetailState {
  const EarningDetailState();
}

final class EarningDetailLoading extends EarningDetailState {
  const EarningDetailLoading();
}

final class EarningDetailError extends EarningDetailState {
  const EarningDetailError(this.error);
  final Object error;
}

final class EarningDetailLoaded extends EarningDetailState {
  const EarningDetailLoaded(this.detail);
  final EarningDetail detail;
}

class EarningDetailBloc extends Bloc<EarningDetailEvent, EarningDetailState> {
  EarningDetailBloc({required this.api, required this.earningId})
      : super(const EarningDetailLoading()) {
    // Rapid Retry taps: only the latest request may emit.
    on<EarningDetailRequested>(_onRequested, transformer: restartable());
  }

  final EarningsApi api;
  final String earningId;

  Future<void> _onRequested(
    EarningDetailRequested event,
    Emitter<EarningDetailState> emit,
  ) async {
    emit(const EarningDetailLoading());
    try {
      emit(EarningDetailLoaded(await api.fetchDetail(earningId)));
    } catch (e) {
      emit(EarningDetailError(e));
    }
  }
}
