part of 'projects_bloc.dart';

sealed class ProjectsEvent {
  const ProjectsEvent();
}

/// Load the next page.
/// - `userInitiated: true`: first load or a Retry tap. Runs even after an error.
/// - `userInitiated: false`: scrolled near the bottom. Ignored while an error
///   is showing, so scrolling doesn't hammer a failing backend.
final class ProjectsNextPageRequested extends ProjectsEvent {
  const ProjectsNextPageRequested({this.userInitiated = false});
  final bool userInitiated;
}

/// Pull-to-refresh: reset to page 0. [onDone] completes when the refresh
/// ends, so RefreshIndicator can stop spinning.
final class ProjectsRefreshRequested extends ProjectsEvent {
  const ProjectsRefreshRequested({this.onDone});
  final Completer<void>? onDone;
}
