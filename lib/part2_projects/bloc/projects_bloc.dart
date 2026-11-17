import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/projects_api.dart';

part 'projects_event.dart';
part 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc({required this.api}) : super(const ProjectsState()) {
    // droppable(): while a page is loading, more "next page" events (several
    // scroll notifications per frame) are dropped, never queued. One request
    // at a time.
    on<ProjectsNextPageRequested>(_onNextPage, transformer: droppable());
    on<ProjectsRefreshRequested>(_onRefresh, transformer: droppable());
  }

  final ProjectsApi api;

  static const pageSize = 20;

  /// An empty page or a short page means there's nothing more.
  static bool _isLastPage(List<Project> page) => page.length < pageSize;

  /// Bumped on refresh. A page load started before it is stale, and its
  /// result is dropped, so a slow page 3 can't land on a fresh page 0.
  /// Needed because the two handlers have separate transformers: a refresh
  /// can't cancel a page load that's in flight.
  int _generation = 0;

  Future<void> _onNextPage(
    ProjectsNextPageRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    if (state.status != ProjectsStatus.idle || state.hasReachedEnd) return;
    if (!event.userInitiated && state.error != null) return;

    final generation = _generation;
    final page = state.nextPage;
    emit(state.copyWith(status: ProjectsStatus.loadingPage, clearError: true));

    try {
      final result = await api.fetchProjects(page);
      if (generation != _generation) return;
      emit(state.copyWith(
        items: List.unmodifiable([...state.items, ...result]),
        nextPage: page + 1,
        hasReachedEnd: _isLastPage(result),
        status: ProjectsStatus.idle,
      ));
    } catch (e) {
      if (generation != _generation) return;
      // Only the error changes: loaded items are never lost.
      emit(state.copyWith(status: ProjectsStatus.idle, error: e));
    }
  }

  Future<void> _onRefresh(
    ProjectsRefreshRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    _generation++; // any in-flight page load is now stale
    // Current items stay on screen until page 0 arrives.
    emit(state.copyWith(status: ProjectsStatus.refreshing));

    try {
      final result = await api.fetchProjects(0);
      emit(ProjectsState(
        items: List.unmodifiable(result),
        nextPage: 1,
        hasReachedEnd: _isLastPage(result),
      ));
    } catch (e) {
      final hasItems = state.items.isNotEmpty;
      emit(state.copyWith(
        status: ProjectsStatus.idle,
        // Nothing on screen: show the full-screen error.
        // Items on screen: keep them and show a snackbar.
        error: hasItems ? null : e,
        refreshFailed: hasItems,
      ));
    } finally {
      event.onDone?.complete();
    }
  }
}
