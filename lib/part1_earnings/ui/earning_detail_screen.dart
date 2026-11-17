import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/formatters.dart';
import '../bloc/earning_detail_bloc.dart';
import '../data/earnings_api.dart';
import '../data/earnings_models.dart';

class EarningDetailPage extends StatelessWidget {
  const EarningDetailPage({super.key, required this.earning});

  final Earning earning;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // The request starts once, when the bloc is created. It doesn't start
      // in build(), so rebuilds can't fire it again.
      create: (context) => EarningDetailBloc(
        api: context.read<EarningsApi>(),
        earningId: earning.id,
      )..add(const EarningDetailRequested()),
      child: _EarningDetailView(earning: earning),
    );
  }
}

class _EarningDetailView extends StatelessWidget {
  const _EarningDetailView({required this.earning});

  final Earning earning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Payout details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show what we already have right away.
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.check_rounded, color: Colors.green.shade700, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '+${formatCurrency(earning.amountInPaise)}',
                    style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(earning.title, style: text.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(earning.earnedAt),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: BlocBuilder<EarningDetailBloc, EarningDetailState>(
                builder: (context, state) => switch (state) {
                  EarningDetailLoading() => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  EarningDetailError() => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: scheme.error),
                          const SizedBox(height: 8),
                          const Text("Couldn't load the details."),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context
                                .read<EarningDetailBloc>()
                                .add(const EarningDetailRequested()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  EarningDetailLoaded(detail: final d) => Column(
                      children: [
                        _DetailRow(
                          icon: Icons.work_outline,
                          label: 'Project',
                          value: d.projectName,
                        ),
                        _DetailRow(
                          icon: Icons.business_outlined,
                          label: 'Company',
                          value: d.companyName,
                        ),
                        _DetailRow(
                          icon: Icons.verified_outlined,
                          label: 'Status',
                          value: d.status,
                        ),
                        _DetailRow(
                          icon: Icons.tag,
                          label: 'Reference',
                          value: d.id,
                        ),
                      ],
                    ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
