import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funngro_assessment/part2_projects/bloc/projects_bloc.dart';
import 'package:funngro_assessment/part2_projects/data/projects_api.dart';

List<Project> page(int p, [int n = 20]) => List.generate(
      n,
      (i) => Project(id: 'p${p * 20 + i}', title: 'P', company: 'C', payout: 1),
    );

/// The test decides when each call resolves or fails.
class ScriptedApi extends ProjectsApi {
  final calls = <int, Completer<List<Project>>>{};
  final requested = <int>[];

  @override
  Future<List<Project>> fetchProjects(int page) {
    requested.add(page);
    return (calls[page] = Completer<List<Project>>()).future;
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

const firstOrRetry = ProjectsNextPageRequested(userInitiated: true);
const scroll = ProjectsNextPageRequested();

void main() {
  late ScriptedApi service;
  late ProjectsBloc bloc;

  setUp(() {
    service = ScriptedApi();
    bloc = ProjectsBloc(api: service);
  });
  tearDown(() => bloc.close());

  Future<void> loadPage(int p, [List<Project>? result]) async {
    bloc.add(firstOrRetry);
    await settle();
    service.calls[p]!.complete(result ?? page(p));
    await settle();
  }

  test('first load error, then retry succeeds', () async {
    bloc.add(firstOrRetry);
    await settle();
    expect(bloc.state.isLoadingPage, isTrue);
    service.calls[0]!.completeError(ApiException('x'));
    await settle();
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.error, isA<ApiException>());

    await loadPage(0);
    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.error, isNull);
  });

  test('failed page load keeps loaded items; scroll does not auto-retry', () async {
    await loadPage(0);

    bloc.add(scroll);
    await settle();
    service.calls[1]!.completeError(ApiException('x'));
    await settle();
    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.error, isNotNull);

    bloc.add(scroll); // scroll event while in error
    await settle();
    expect(service.requested, [0, 1]);

    await loadPage(1); // explicit retry
    expect(bloc.state.items, hasLength(40));
    expect(bloc.state.items.last.id, 'p39');
  });

  test('a burst of page requests causes one fetch (droppable)', () async {
    bloc
      ..add(firstOrRetry)
      ..add(firstOrRetry)
      ..add(scroll);
    await settle();
    expect(service.requested, [0]);
  });

  test('empty page marks end of list', () async {
    await loadPage(0);
    await loadPage(1, []);
    expect(bloc.state.hasReachedEnd, isTrue);
    bloc.add(firstOrRetry);
    await settle();
    expect(service.requested, [0, 1]);
  });

  test('refresh resets to page 0 and drops an in-flight stale page', () async {
    await loadPage(0);

    bloc.add(scroll); // page 1 in flight
    await settle();
    final done = Completer<void>();
    bloc.add(ProjectsRefreshRequested(onDone: done));
    await settle();
    final stalePage1 = service.calls[1]!;
    service.calls[0]!.complete(page(0));
    await done.future;
    stalePage1.complete(page(1)); // arrives late: must be ignored
    await settle();

    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.items.first.id, 'p0');
    expect(bloc.state.isLoadingPage, isFalse);

    await loadPage(1); // continues from page 1 after the reset
    expect(bloc.state.items, hasLength(40));
  });

  test('failed refresh keeps existing items and flags the snackbar', () async {
    await loadPage(0);

    final done = Completer<void>();
    bloc.add(ProjectsRefreshRequested(onDone: done));
    await settle();
    service.calls[0]!.completeError(ApiException('x'));
    await done.future;

    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.isRefreshing, isFalse);
    expect(bloc.state.refreshFailed, isTrue);
    expect(bloc.state.error, isNull); // no full-screen/footer error over the list
  });
}
