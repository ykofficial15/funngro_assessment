import 'dart:math';

// The assessment's API, unchanged, plus the two types it uses.

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.company,
    required this.payout,
  });

  final String id;
  final String title;
  final String company;
  final int payout;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

class ProjectsApi {
  final _rng = Random();

  /// Returns 20 projects per page. Pages 0..7 exist.
  /// ~900ms latency. Fails (throws ApiException) roughly 1 in 5 calls.
  Future<List<Project>> fetchProjects(int page) async {
    await Future.delayed(Duration(milliseconds: 900));
    if (_rng.nextInt(5) == 0) throw ApiException('server error');
    if (page > 7) return [];
    return List.generate(20, (i) => Project(
      id: 'p${page * 20 + i}',
      title: 'Project ${page * 20 + i}',
      company: 'Company ${_rng.nextInt(50)}',
      payout: 200 + _rng.nextInt(1800),
    ));
  }
}

/// Demo aid for the recording only. Forces the next call to fail so the
/// error/retry path can be shown on demand instead of waiting for the 1-in-5.
class DemoProjectsApi extends ProjectsApi {
  bool failNextCall = false;

  @override
  Future<List<Project>> fetchProjects(int page) async {
    if (failNextCall) {
      failNextCall = false;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      throw ApiException('forced failure (demo)');
    }
    return super.fetchProjects(page);
  }
}
