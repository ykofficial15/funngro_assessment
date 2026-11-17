import 'package:flutter/material.dart';

/// Full-screen message for error and empty states: icon, title, message and
/// an optional action. Scrollable, so pull-to-refresh still works on it.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        isError ? scheme.errorContainer : scheme.primaryContainer,
                    child: Icon(
                      icon,
                      size: 40,
                      color: isError
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: text.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows shown during the first load, shaped like the real rows
/// so the layout doesn't jump when data arrives. Static (no shimmer
/// animation), so it costs nothing on a cheap phone.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 8, this.header});

  final int itemCount;

  /// Optional placeholder shown above the rows (e.g. a summary card).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ?header, // added only when non-null
        for (var i = 0; i < itemCount; i++) const _SkeletonRow(),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(160, 14), const SizedBox(height: 8), bar(90, 12)],
            ),
          ),
          bar(64, 16),
        ],
      ),
    );
  }
}

/// Placeholder block, e.g. for a summary card while loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
