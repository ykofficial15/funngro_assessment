import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/formatters.dart';
import '../../common/widgets.dart';
import '../bloc/projects_bloc.dart';
import '../data/projects_api.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectsBloc(api: context.read<ProjectsApi>())
        ..add(const ProjectsNextPageRequested(userInitiated: true)),
      child: const ProjectsView(),
    );
  }
}

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  /// Start the next page while the user is still a few rows from the bottom,
  /// so the 900ms latency is mostly hidden.
  static const _loadMoreThreshold = 400.0;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProjectsBloc>();
    final api = context.read<ProjectsApi>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          if (kDebugMode && api is DemoProjectsApi)
            IconButton(
              tooltip: 'Fail next request (demo)',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () {
                api.failNextCall = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Next request will fail')),
                );
              },
            ),
          const SizedBox(width: 8), // keeps the icon clear of the back-gesture edge
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final done = Completer<void>();
          bloc.add(ProjectsRefreshRequested(onDone: done));
          return done.future;
        },
        child: BlocConsumer<ProjectsBloc, ProjectsState>(
          listenWhen: (_, curr) => curr.refreshFailed,
          listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't refresh. Showing earlier results.")),
          ),
          builder: (context, state) => _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProjectsState state) {
    final bloc = context.read<ProjectsBloc>();

    if (state.items.isEmpty) {
      if (state.error != null) {
        return StatusView(
          isError: true,
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load projects",
          message: 'Something went wrong on our side. Please try again.',
          actionLabel: 'Retry',
          onAction: () =>
              bloc.add(const ProjectsNextPageRequested(userInitiated: true)),
        );
      }
      if (state.hasReachedEnd) {
        return const StatusView(
          icon: Icons.work_off_outlined,
          title: 'No projects right now',
          message: 'New projects are added every day. Pull down to check again.',
        );
      }
      // Loading, or the first frame before the first event is handled.
      return const SkeletonList();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < _loadMoreThreshold &&
            bloc.state.canAutoLoad) {
          bloc.add(const ProjectsNextPageRequested());
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            // Fixed-extent and lazy: only visible cards are built.
            sliver: SliverFixedExtentList(
              itemExtent: ProjectCard.height,
              delegate: SliverChildBuilderDelegate(
                childCount: state.items.length,
                (context, index) {
                  final p = state.items[index];
                  return ProjectCard(key: ValueKey(p.id), project: p);
                },
              ),
            ),
          ),
          // Footer: loading / error + Retry / end of list.
          SliverToBoxAdapter(child: _Footer(state: state)),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project});

  static const double height = 92;

  final Project project;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.work_outline, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            project.company,
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  formatRupees(project.payout),
                  style: text.labelLarge?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});
  final ProjectsState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final Widget child;

    if (state.isLoadingPage) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Loading more projects…', style: text.bodyMedium),
        ],
      );
    } else if (state.error != null) {
      child = Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Couldn't load more projects.",
                style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context
                  .read<ProjectsBloc>()
                  .add(const ProjectsNextPageRequested(userInitiated: true)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (state.hasReachedEnd) {
      child = Column(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.primary),
          const SizedBox(height: 6),
          Text("You're all caught up", style: text.titleSmall),
          Text(
            '${state.items.length} projects',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    } else {
      child = const SizedBox(height: 18);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(child: child),
    );
  }
}
