import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/formatters.dart';
import '../../common/widgets.dart';
import '../bloc/earnings_bloc.dart';
import '../data/earnings_api.dart';
import '../data/earnings_models.dart';
import 'earning_detail_screen.dart';

/// Wires the bloc to the route. BlocProvider creates it when the route is
/// pushed and calls close() when the route is removed. That cancels the
/// wallet subscription: no leak, no setState-after-dispose.
class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // A new userId (account switch) changes the key, so Flutter throws
      // away the old provider (closing the old user's bloc) and makes a new one.
      key: ValueKey(userId),
      create: (context) => EarningsBloc(
        api: context.read<EarningsApi>(),
        userId: userId,
      )..add(const EarningsStarted()),
      child: const EarningsView(),
    );
  }
}

class EarningsView extends StatefulWidget {
  const EarningsView({super.key});

  @override
  State<EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<EarningsView> {
  bool _navigating = false;

  Future<void> _refresh() {
    final done = Completer<void>();
    context.read<EarningsBloc>().add(EarningsLoadRequested(onDone: done));
    return done.future; // keeps the RefreshIndicator spinning until the load ends
  }

  Future<void> _openDetail(Earning earning) async {
    // Ignore a second tap that lands before the route is on screen.
    if (_navigating) return;
    _navigating = true;
    // Navigate straight away. The detail screen has its own bloc with its
    // own loading/error states, so taps never feel dead and we never use
    // `context` after an await on this screen.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EarningDetailPage(earning: earning)),
    );
    _navigating = false; // plain field, no setState: safe even if unmounted
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: BlocConsumer<EarningsBloc, EarningsState>(
        // Side effects (snackbar) go in the listener, never in the builder.
        listenWhen: (_, curr) => curr is EarningsLoaded && curr.refreshFailed,
        listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't refresh. Showing saved earnings.")),
        ),
        builder: (context, state) => switch (state) {
          EarningsLoading() =>
            const SkeletonList(header: SkeletonBox(height: 132)),
          EarningsError() => StatusView(
              isError: true,
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your earnings",
              // Say plainly that the money is safe. A blank list on a money
              // screen reads as "my earnings are gone".
              message: 'Your money is safe. Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () =>
                  context.read<EarningsBloc>().add(const EarningsLoadRequested()),
            ),
          EarningsLoaded(items: final items) when items.isEmpty => RefreshIndicator(
              onRefresh: _refresh,
              child: const StatusView(
                icon: Icons.savings_outlined,
                title: 'No earnings yet',
                message: 'Complete your first project and your payouts will show up here.',
              ),
            ),
          EarningsLoaded() => RefreshIndicator(
              onRefresh: _refresh,
              child: _EarningsList(state: state, onTap: _openDetail),
            ),
        },
      ),
    );
  }
}

class _EarningsList extends StatelessWidget {
  const _EarningsList({required this.state, required this.onTap});

  final EarningsLoaded state;
  final ValueChanged<Earning> onTap;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryCard(
            totalInPaise: state.totalInPaise,
            count: items.length,
            isRefreshing: state.isRefreshing,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text('History', style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        // Lazy and fixed-extent: only rows in the viewport plus cacheExtent
        // (~15) are built, never 3,000, and scroll offsets come from
        // arithmetic instead of measuring each row.
        SliverFixedExtentList(
          itemExtent: EarningTile.height,
          delegate: SliverChildBuilderDelegate(
            childCount: items.length,
            (context, index) {
              final earning = items[index];
              return EarningTile(
                // Inserting at index 0 shifts every index. The key stops a
                // row's element/state from being reused for a different earning.
                key: ValueKey(earning.id),
                earning: earning,
                onTap: () => onTap(earning),
              );
            },
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalInPaise,
    required this.count,
    required this.isRefreshing,
  });

  final int totalInPaise;
  final int count;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                'Total earned',
                style: text.titleSmall?.copyWith(color: scheme.onPrimary),
              ),
              const Spacer(),
              if (isRefreshing)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCurrency(totalInPaise),
            style: text.headlineMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCount(count)} payouts',
            style: text.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class EarningTile extends StatelessWidget {
  const EarningTile({super.key, required this.earning, required this.onTap});

  static const double height = 76;

  final Earning earning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.south_west_rounded, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    earning.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(earning.earnedAt),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${formatCurrency(earning.amountInPaise)}',
              style: text.titleSmall?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
