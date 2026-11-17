import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'part1_earnings/data/earnings_api.dart';
import 'part1_earnings/ui/earnings_screen.dart';
import 'part2_projects/data/projects_api.dart';
import 'part2_projects/ui/projects_screen.dart';

void main() => runApp(const AssessmentApp());

class AssessmentApp extends StatelessWidget {
  const AssessmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The APIs are app-wide singletons, provided above MaterialApp so every
    // route can read them. Blocs are per screen and live in each page's
    // BlocProvider.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EarningsApi>(create: (_) => FakeEarningsApi()),
        RepositoryProvider<ProjectsApi>(create: (_) => DemoProjectsApi()),
      ],
      child: MaterialApp(
        title: 'Funngro Assessment',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const _Home(),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B4BDB),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Funngro Assessment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Part 1 · My Earnings',
            subtitle: '3,000 payouts, live wallet updates, detail screen',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const EarningsPage(userId: 'demo-user'),
            )),
          ),
          const SizedBox(height: 12),
          _HomeCard(
            icon: Icons.work_outline,
            title: 'Part 2 · Projects',
            subtitle: 'Infinite scroll on a flaky API (1 in 5 calls fail)',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ProjectsPage(),
            )),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
