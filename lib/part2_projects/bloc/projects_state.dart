part of 'projects_bloc.dart';

enum ProjectsStatus { idle, loadingPage, refreshing }

/// One state class with facts the UI combines, instead of a separate class
/// per state. The visible states overlap: "page 3 failed" still has to show
/// pages 0–2.
///
///                    items empty              items present
///   loading     ->   first-load spinner       footer spinner
///   error       ->   full-screen error        footer error + Retry
///   end         ->   empty state              footer "end of list"
final class ProjectsState {
  const ProjectsState({
    this.items = const [],
    this.nextPage = 0,
    this.status = ProjectsStatus.idle,
    this.error,
    this.hasReachedEnd = false,
    this.refreshFailed = false,
  });

  final List<Project> items; // unmodifiable
  final int nextPage;
  final ProjectsStatus status;
  final Object? error;
  final bool hasReachedEnd;

  /// One-shot flag for the "couldn't refresh" snackbar. Not carried over by
  /// copyWith.
  final bool refreshFailed;

  bool get isLoadingPage => status == ProjectsStatus.loadingPage;
  bool get isRefreshing => status == ProjectsStatus.refreshing;

  /// Lets the UI skip adding events on every scroll tick.
  bool get canAutoLoad =>
      status == ProjectsStatus.idle && !hasReachedEnd && error == null;

  ProjectsState copyWith({
    List<Project>? items,
    int? nextPage,
    ProjectsStatus? status,
    Object? error,
    bool clearError = false,
    bool? hasReachedEnd,
    bool refreshFailed = false,
  }) =>
      ProjectsState(
        items: items ?? this.items,
        nextPage: nextPage ?? this.nextPage,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
        hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
        refreshFailed: refreshFailed,
      );
}
