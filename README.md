# Funngro: Mobile Engineering Assessment (Flutter)

My submission for the Funngro mobile engineer take-home. The code for Parts 1 and 2 is in this repo; the written answers for every part are below.

| Part | What | Where |
|---|---|---|
| 1 | Code review + rewrite of the earnings screen | [Answers](#part-1-code-review-of-the-earnings-screen) · `lib/part1_earnings/` |
| 2 | Projects list with infinite-scroll pagination | [Answers](#part-2-projects-list-with-pagination) · `lib/part2_projects/` |
| 3 | Production scenario (crash in staged rollout) | [Answers](#part-3-production-scenario) |
| 4 | Walkthrough recording | [Link](#part-4-walkthrough-recording) |
| — | Questions I'd ask you | [List](#questions-id-ask-you) |

**Stack:** Flutter 3.47.2, `flutter_bloc` + `bloc_concurrency` for state (bloc / event / state per screen), `intl` for formatting. 13 tests (bloc tests for both parts + a widget test proving the 3,000-row list only builds visible rows).

## Run

```bash
flutter pub get
flutter run            # pick Part 1 or Part 2 from the home screen
flutter test           # bloc tests + a widget test for the 3,000-row list
```

Tested with Flutter 3.47.2. Added dependencies: `flutter_bloc`, `bloc_concurrency`, `intl` (currency formatting).

## Layout

Each part is split into API (data) → bloc (event/state) → UI, using `flutter_bloc` and `bloc_concurrency`.

```
lib/
  main.dart                          provides the APIs (MultiRepositoryProvider) + theme
  common/
    formatters.dart                  currency / date / count formatters, built once
    widgets.dart                     StatusView (error/empty), SkeletonList (first load)
  part1_earnings/
    data/
      earnings_api.dart              EarningsApi interface + FakeEarningsApi (3,000 rows, live updates)
      earnings_models.dart
    bloc/
      earnings_bloc.dart             fetch + wallet subscription lifecycle + running total
      earnings_event.dart            Started / LoadRequested / (private) EarningReceived
      earnings_state.dart            Loading / Error / Loaded
      earning_detail_bloc.dart       detail screen's bloc, events and states
    ui/
      earnings_screen.dart           EarningsPage (BlocProvider) + EarningsView
      earning_detail_screen.dart
  part2_projects/
    data/
      projects_api.dart              the provided ProjectsApi, unchanged (+ demo subclass)
    bloc/
      projects_bloc.dart             pagination with droppable() + refresh
      projects_event.dart            NextPageRequested / RefreshRequested
      projects_state.dart
    ui/
      projects_screen.dart           ProjectsPage (BlocProvider) + ProjectsView
test/
  earnings_bloc_test.dart
  projects_bloc_test.dart
```

## Demoing the error path (Part 2)

The API fails about 1 in 5 calls at random. For a reliable demo, tap the **bug icon** in the Projects app bar (debug builds only) and the *next* request fails:
- tap it before scrolling to the bottom to show the footer error with Retry, with the loaded items kept;
- tap it before pulling to refresh to show the "Couldn't refresh" snackbar, with the items kept.

---

## Part 1: Code review of the earnings screen

> **Task:** the provided `EarningsScreen` works in the demo but would cause crashes, jank and support tickets in production (800–3,000 entries, a ₹8,000 Android phone, one of the most-visited screens).
> 1. List every problem, ordered by user impact: what the user experiences, why it happens, and the fix.
> 2. Rewrite the screen the way I'd ship it, with loading/error/empty states, correct subscription lifecycle, and a list that stays smooth at 3,000 items.
> 3. In 3–5 sentences: what conventions or guardrails would stop the other 59 screens repeating these mistakes?

### 1.1 Problems, worst first

Context: 800–3,000 rows, an ₹8k Android phone (slow CPU, 2–3 GB RAM, often on mobile data), and one of the most-visited screens.

#### 1. Network request and subscription started inside `build()`, which loops forever
- **What the user sees:** the screen never settles. The phone heats up, the battery drains, and mobile data keeps going (most teens are on prepaid packs). The list keeps resetting.
- **Why:** `build()` isn't called once. The framework calls it every time the element is marked dirty: on mount, on every `setState`, and on every change to an inherited dependency (MediaQuery from the keyboard or rotation, Theme, locale, and so on). Here the screen dirties itself:
  1. `build` calls `fetchEarnings`.
  2. `.then` calls `setState`, which marks the element dirty.
  3. On the next frame `build` runs again and starts another `fetchEarnings`.

  This repeats roughly once per API round trip for as long as the screen is open. Each pass also adds another stream subscription (see #3) and re-runs the 3,000-row build (see #2). Server-side, every open earnings screen sends a full history request about every second. On our most-visited endpoint, that's a self-inflicted DDoS that slows the app down for everyone.
- **Fix:** `build()` must be pure: it only describes UI. Start work once, in `initState` (or, in async_redux, a `StoreConnector.onInit` that dispatches a fetch action). In my version, the `BlocProvider` creates `EarningsBloc` once per route and adds `EarningsStarted`. Nothing is started from `build()`.

I rank this first because it's the root cause. It turns every other cost on this list from a one-off into one that repeats forever, and it's the only bug that also harms users who aren't on this screen (backend load).

#### 2. All 3,000 rows built, laid out and formatted eagerly on the UI thread
- **What the user sees:** the screen freezes for seconds when it opens (3,000 × ~3 ms `formatCurrency` ≈ **9 s** of synchronous work, before the widget work itself). The same freeze happens again on every `setState`: every wallet update and every detail tap. Back in the background, a large retained tree raises the chance that Android's low-memory killer kills the app.
- **Why:** `SingleChildScrollView` + `Column` has no laziness. `.map(...).toList()` creates 3,000 `EarningTile` widgets up front. The Column inflates 3,000 elements and render objects, lays all of them out (it has to, to know its height), and paints them all (the scroll view only clips). `formatCurrency` runs inside that `map`, so it runs 3,000 times per build on the UI isolate.
- **Fix:** `ListView.builder` only builds rows in the viewport plus `cacheExtent` (about 15 on a phone), with a fixed `itemExtent` so the list never measures rows to work out scroll offsets. Build the `NumberFormat` once (the 3 ms is locale parsing, not formatting). Only visible rows get formatted, so even an unfixed 3 ms formatter would cost about 3–6 ms per frame while scrolling, not 9 s. Also: a 3,000-row JSON payload is itself 50–150 ms of decode on this hardware, so I'd ask for server-side pagination or decode with `Isolate.run`.

#### 3. Stream subscriptions multiply and are never cancelled
- **What the user sees:** one new payout shows up **N times** in the list, where N is how many builds have happened so far. Then a refetch replaces the list and the extra rows vanish. On a money screen that means "I got paid 40 times?" or "my money disappeared?" support tickets. Leaving the screen doesn't stop any of it: memory and battery use climb all session.
- **Why:** each `build` calls `.listen(...)` again, and nothing keeps or cancels the `StreamSubscription`. Each closure captures the `State`, so after the route pops, the State, its 3,000-item list and everything it references can't be garbage collected. Every visit to the screen leaks another set. Every later update calls `setState` on a disposed State. In debug that's the "setState() called after dispose()" assertion. In release `_element` is already null, so `_element!.markNeedsBuild()` throws a null-check error: an uncaught async error logged to Crashlytics for every update × every leaked subscription.
- **Fix:** subscribe once in `initState` and cancel in `dispose`. Dedupe updates by id. (In the rewrite, `EarningsBloc` owns the subscription and `close()` cancels it. `BlocProvider` calls `close()` when the route is removed. There's a test for this.)

#### 4. No loading, error or empty state: a blank screen looks like lost money
- **What the user sees:** a blank list while the data loads (and freezes), and a permanently blank list if the request fails, with no retry. "No earnings" and "failed to load" look the same. On a screen about the user's money, that's the most alarming thing it could show.
- **Why:** `loading` starts as `false` and is never set to `true`, so the spinner can never appear. `.then` has no `onError` or `catchError`, so a failure becomes an unhandled Future error (Crashlytics noise) and the state never changes.
- **Fix:** explicit states: loading / error + retry / empty / loaded. A failed refresh keeps the data already on screen and shows a snackbar.

#### 5. Detail tap: no feedback, double pushes, and `context` / `setState` used after `await`
- **What the user sees:** on 3G, tapping does nothing for 0.5–1 s, so users tap again. That sends several requests and pushes the same detail screen 2–3 times, so Back shows the same page repeatedly. If `fetchDetail` fails, the tap silently does nothing. Just before the push, `setState` rebuilds the whole 3,000-row Column (another freeze from #2), so the page transition janks.
- **Why:** there's no `mounted` check after `await`. If the user has left the screen, `setState` throws, and `Navigator.push(context)` with an unmounted element throws "Looking up a deactivated widget's ancestor is unsafe". (The `use_build_context_synchronously` lint flags exactly this.) `e.detail = detail` also changes a shared model in place, for data the list never shows.
- **Fix:** navigate immediately. The detail screen has its own `EarningDetailBloc` with loading and error states. The request starts when the bloc is created, not in `build`, so rebuilds can't refetch. A `_navigating` flag drops a second tap. No `context` use after `await` on the list screen.

#### 6. Data races: stale responses and lost or duplicated live updates
- **What the user sees:** the list occasionally jumps back to older data, and a payout that just arrived disappears or shows twice.
- **Why:** overlapping fetches (because of #1) can complete out of order, so an older response overwrites a newer one. `earnings = data` replaces the list and drops wallet updates that arrived before the fetch finished. Or, if the server already includes that update, it's counted twice, because nothing dedupes by id.
- **Fix:** subscribe before fetching. Buffer updates that arrive while a fetch is in flight, or while there's no list on screen (loading or error). Merge them into the next successful result, deduped by id. Load events use `restartable()`, so a new load cancels the old handler and its late response can't emit.

#### 7. Prepending without keys
- **Why:** `insert(0, ...)` shifts every child by one position. Without keys, Flutter matches old and new children by type and position, so every element gets updated with its neighbour's data, and any state inside a tile (ink ripple, expansion, an image already loaded) sticks to the wrong earning.
- **Fix:** `key: ValueKey(earning.id)`.

#### 8. Smaller items
- A `userId` change (account switch) isn't handled. Once #1 is fixed, the screen would keep the old user's stream, so the bloc has to be recreated (I key the `BlocProvider` by `userId`). (The original only "works" here because it refetches on every build.)
- The global `api` is a hidden dependency that can't be tested, so I inject it.
- No `const` constructor or `key`. Mutable public state fields.
- Money should be integer minor units (paise), not `double`. I've assumed `amount` is money and modelled it as `amountInPaise`.

### 1.2 Rewrite

Layers: **API** (one data file per feature: the network calls, returning domain models) → **bloc** (events in, states out) → **UI**. I kept one data layer rather than a service plus a repository: with no caching or merging of sources, a repository would only forward calls.

- `lib/part1_earnings/data/`
  - `earnings_api.dart`: the `EarningsApi` interface (the only thing the blocs talk to) + `FakeEarningsApi` (3,000 rows, a live payout every 6 s, random failures).
- `lib/part1_earnings/bloc/`
  - `earnings_bloc.dart`, with `earnings_event.dart` and `earnings_state.dart` as part files.
  - Events: `EarningsStarted`, `EarningsLoadRequested` (first load, retry, refresh), and a private `_EarningReceived` for live updates.
  - Sealed states: `EarningsLoading` / `EarningsError` / `EarningsLoaded(items, isRefreshing, refreshFailed)`.
  - The bloc subscribes before fetching, buffers and dedupes updates, and cancels the subscription in `close()`.
  - `restartable()` on load events: a newer load cancels the old one, so a stale response can't overwrite fresh data.
- `lib/part1_earnings/bloc/earning_detail_bloc.dart`: the detail screen's own bloc (`restartable()` so rapid Retry taps can't race).
- `lib/part1_earnings/ui/earnings_screen.dart`
  - `EarningsPage` provides the bloc, keyed by `userId` (account switch → old bloc closed, new one created).
  - `EarningsView` uses `BlocConsumer`: the builder renders states, and the listener shows the one-shot "couldn't refresh" snackbar.
  - A `CustomScrollView` with a summary card and a lazy `SliverFixedExtentList` (fixed row height, `ValueKey`s), plus pull-to-refresh.
- `lib/common/formatters.dart`: currency/date formatters built once. `lib/common/widgets.dart`: shared `StatusView` (error/empty) and `SkeletonList` (first load).

The APIs are provided app-wide with `MultiRepositoryProvider` above `MaterialApp`. Blocs are per screen. The bloc state also carries a running `totalInPaise` for the summary card, so `build` never sums 3,000 items.

Mapped onto your async_redux:
- Events become actions.
- The bloc's handlers become the actions' `reduce()`.
- The sealed state becomes the ViewModel, with `==` so the connector only rebuilds when the VM changes.
- The subscription is set up in `StoreConnector.onInit` and torn down in `onDispose`.

### 1.3 Guardrails for the other 59 screens

I'd make most of these mistakes fail CI instead of relying on review:
- Turn on the lints that catch them: `cancel_subscriptions`, `close_sinks`, `use_build_context_synchronously`, `discarded_futures` / `unawaited_futures` (these flag a bare `api.fetch().then(...)` inside `build`).
- Add a small custom lint (or a DCM rule) that rejects `.map(...).toList()` as children of a `Column` / `SingleChildScrollView` over list data.
- Set an architecture rule that widgets never call `api` directly. Data comes from the store through actions dispatched in `onInit`, and subscriptions live in one lifecycle-aware place, so `build()` stays pure by construction.
- Provide shared `AsyncView` and `PagedListView` components that require loading, error, empty and data builders, so the right thing is also the least work.
- Add a performance gate: an integration test that opens the top 10 screens with production-size fixtures (3,000 rows) on a low-end device profile and fails the PR if p90 frame build time goes over 16 ms or memory grows after a push/pop loop.

---

## Part 2: Projects list with pagination

> **Task:** build one screen against the provided flaky `ProjectsApi` (20 per page, pages 0–7, ~900 ms latency, fails ~1 in 5 calls). Infinite scroll with first-load, page-load, error (with retry) and end-of-list states all visually distinct; a failed page load must not lose loaded items; pull-to-refresh resets to page 0.

Code: `lib/part2_projects/`. Layers: `data/projects_api.dart` (the provided `ProjectsApi`, unchanged) → `bloc/` (`ProjectsBloc`, events, state) → `ui/projects_screen.dart`. Tests: `test/projects_bloc_test.dart`.

**Events:** `ProjectsNextPageRequested(userInitiated)` and `ProjectsRefreshRequested`.

**State model:** one `ProjectsState` class (not one class per state, because the states overlap: a page-3 error still shows pages 0–2). It holds `items`, `nextPage`, `status` (idle / loadingPage / refreshing), `error`, `hasReachedEnd` and a one-shot `refreshFailed`. The screen works out which visually distinct state to show from those:

| | Nothing loaded yet | Items on screen |
|---|---|---|
| Loading | Skeleton placeholder rows | Footer: small spinner, "Loading more projects…" |
| Error | Full-screen illustration, message, **Retry** button | Footer: error-coloured banner with **Retry**; items kept |
| End | Empty state | Footer: "You're all caught up · 160 projects" |

**Decisions worth defending:**
- **A failed page never loses items.** The error only sets `error`. `items` is only replaced on a successful refresh.
- **No auto-retry on scroll after an error.** Otherwise every scroll event near the bottom would re-fire against a failing API. The user retries on purpose: scroll sends `userInitiated: false`, which is ignored while an error is showing; the Retry button sends `true`.
- **One request at a time.** Page events use `droppable()`: while a page is loading, the several scroll notifications per frame are dropped, not queued.
- **Pull-to-refresh** fetches page 0 while the current items stay visible, then replaces them. If it fails, the items stay and a snackbar says so. A **generation counter** discards any page load that was already in flight (needed because refresh and page events have separate transformers, so a refresh can't cancel the page handler), so a slow page 3 can't append to a fresh page 0. There's a test for this.
- **End detection:** an empty page *or* a short page (< 20) means the end. That saves one extra 900 ms request when the last page isn't full.
- **Prefetching:** the next page loads when the user is within about 400 px of the bottom, which hides most of the 900 ms latency.
- **Demo aid:** in debug builds there's a bug icon in the app bar that forces the *next* call to fail, so I can show the error and retry path on camera without waiting for the 1-in-5 failure. It's a subclass of the API; the API itself is unchanged.

**Assumptions / questions for you:**
- Should a failed page load auto-retry once with backoff before showing the Retry button? I chose manual-only to protect the backend.
- On refresh, should the list clear immediately, or (as I did) keep stale items until page 0 arrives?
- Offset pagination plus inserts on the server can cause duplicates or skipped items between pages. Does the real API support cursor-based pagination?

---

## Part 3: Production scenario

> **Task:** v6.4.0 is at 20% staged rollout. Crashlytics shows a new `PlatformException` in the ad SDK on app resume; crash-free users in the rollout group dropped from 99.6% to 98.1%. The ad SDK wasn't updated. Ad revenue matters, and the founder is asking whether to halt. Write the reply to the founder, then the plan for the day: what to check first in Crashlytics, which device/OS patterns to look for, how to decide between halt / hold at 20% / fix-forward, and which Remote Config or feature-flag lever I'd want (and whether I'd have shipped one).

### Message to the founder

> Yes, I'm halting the rollout now. It's one click and fully reversible, and it only stops *new* users getting 6.4.0. The 80% on 6.3.x are unaffected and their ads keep running normally, so the halt costs us no ad revenue.
>
> Why I'm not waiting: in the rollout group, about 1 in 50 daily users now crash when they return to the app (it was 1 in 250). If that reaches everyone, Play's Android vitals thresholds would start hurting our store ranking for all users, not just the 20%.
>
> Play can't roll back the 20% who already have 6.4.0, so the real fix is a 6.4.1. I'll have the cause and a plan by 1 pm: either it's not our release and we resume, or we ship a fix (or a rebuilt 6.3.x with a higher version number) with a slow ramp.

### Investigation plan for the day

**0. Protect first (first 15 min).** Do a 5-minute sanity check that the crash only appears on 6.4.0 and the sample isn't tiny (20% of our DAU is tens of thousands, so it won't be). Then **Halt** in Play Console. *Hold at 20%* is not the same as halt: more devices in the 20% cohort keep updating while it's held. Halting protects users and is reversible. Deciding between fix and resume waits for the data.

**1. Crashlytics, in this order:**
1. **Version split.** Does the same issue appear on 6.3.x too, rising today? If yes, the cause is environmental (a Play Services, Android System WebView or ad-server-side change, since ads render in WebView) and not our release. Halting wouldn't help in that case.
2. **Is it really fatal?** A `PlatformException` comes from a MethodChannel call in Dart, so it's a Dart exception, not a native crash. It only shows up as a *crash* if our error handler records it with `fatal: true` (`PlatformDispatcher.onError → recordError(..., fatal: true)`). Check whether 6.4.0 changed that wiring, and cross-check with **Play Console Android vitals**, which only counts real process deaths. If users aren't actually crashing, this is a reporting change plus a missing `try/catch`. That's still worth fixing, but it changes the urgency.
3. **Stack trace and breadcrumbs:** which channel method (load, show, dispose), what the app was doing before resume, how long it was in the background, and which ad format (app-open-on-resume is the classic suspect).

**2. Device and OS patterns to look for:**
- **Low RAM / Android Go devices and aggressive OEMs** (Xiaomi, Realme, Oppo, Vivo). The process or Activity was killed in the background and recreated on resume, and the ad plugin is called with a stale or null Activity, or before the engine has reattached.
- **OS version clustering:** for example, only Android 14/15 would point to a `targetSdk` bump in 6.4.0 and its behaviour changes.
- **WebView / Play Services version clustering:** points to an environmental cause.
- **ABI (32-bit vs 64-bit):** points to a native library or R8/minify problem.

**3. What changed if "the ad SDK didn't":** diff v6.3.x..v6.4.0 for:
- `pubspec.lock` (transitive plugin bumps, including the Flutter ads plugin wrapper)
- Flutter SDK / engine version
- `android/` build config: `targetSdk`, AGP, R8 full mode / ProGuard rules stripping classes the ad SDK loads by reflection, mediation adapters
- `MainActivity`
- any new `AppLifecycleListener` / `didChangeAppLifecycleState` code that runs on resume

Then reproduce on a matching low-end device with **Developer options → Don't keep activities** and a background → resume cycle.

**4. Decision:**
- **Same rate on 6.3.x (environmental):** resume the rollout and fix it separately.
- **Ours, and not a real process death (reporting only):** fix forward in 6.4.1. Resuming 6.4.0 is acceptable meanwhile.
- **Ours and real, with a small, understood fix (e.g. a guarded ad call on resume):** fix forward in 6.4.1 within 1–2 days. Ramp 5% → 20% → 50% → 100%, with a crash-free target of ≥ 99.5% at each step before widening.
- **Ours and real, with no clear fix today:** ship 6.4.1 = 6.3.x code with a higher versionCode, to rescue the 20% stuck on 6.4.0.

**5. The lever I wish I had, and yes, I'd have shipped it:**
- A **Remote Config kill switch per ad placement** (e.g. `ads_app_open_on_resume_enabled`), targetable by app version, Android version and device model. With it, the fix is "turn off one placement for 6.4.0 on the affected cohort" in minutes. No release, the rest of ad revenue stays, and the rollout can resume.
- The flag has to be cached and activated at startup so it applies before the resume path runs.
- Every third-party SDK call on a lifecycle hot path should also go through a wrapper that catches `PlatformException`, records it as non-fatal, and skips the ad. An ad that fails to show is a lost impression; a crash is a lost user.

---

## Part 4: Walkthrough recording

> **Task:** a ≤5-minute screen recording showing the Part 2 screen running (including the error/retry path), the worst bug from Part 1 and why it's ranked first, and one decision I wasn't sure about.

**Recording:** _link to be added_

---

## Questions I'd ask you

1. **Earnings API:** does it paginate? Returning 3,000 rows at once is a payload and decode problem on these phones, whatever the UI does.
2. **Live updates while the user is scrolled down:** should they insert at the top (what I did, which shifts the visible content by one row) or show a "1 new payout ↑" pill?
3. **Crashlytics setup:** do we record uncaught Dart errors as `fatal: true`? That changes how to read the Part 3 numbers.
4. **Ad formats:** which formats run on resume (app-open ads?), and is any Remote Config / feature-flag system already in the app?
5. **Pagination failures:** auto-retry with backoff, or manual only?
