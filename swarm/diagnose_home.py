#!/usr/bin/env python3
"""15-agent headless `claude -p` swarm: diagnose why the YardSale JA home/browse
feed loads NOTHING on first web paint (only populates after a manual reload)."""
import subprocess, concurrent.futures, pathlib, textwrap, sys, time

PROJECT = "/home/kopi/projects/yardsale_ja"
OUTDIR = pathlib.Path(PROJECT, "swarm", "out")
OUTDIR.mkdir(parents=True, exist_ok=True)

SYMPTOM = textwrap.dedent("""
    SYMPTOM: YardSale JA (Flutter web). On a FRESH browser load, the home tab
    (BrowseScreen) shows shimmer skeletons forever and NO auctions appear.
    A manual page RELOAD fixes it: 25 seeded auctions then render correctly.
    So data + seeding work; something on the FIRST load leaves the feed empty
    or stuck loading. Native (Android) is reportedly fine.

    Key facts already known:
    - Feed gating: lib/screens/browse/browse_screen.dart:47  `if (provider.isLoading) return _buildShimmer();`
    - Provider: lib/providers/listing_provider.dart (ChangeNotifier, isLoading flag)
    - Repo query: lib/data/repositories/listing_repository.dart getListings()
      defaults to WHERE l.status = 'active' (args.add(status ?? 'active')).
    - DB: lib/data/database/database_helper.dart — web branch sets
      databaseFactory = databaseFactoryFfiWeb (OPFS); _onCreate -> _seedData(db)
      seeds users + 25 listings; resetDatabase() exists.
    - main.dart wires ListingProvider via MultiProvider.
""").strip()

RULES = textwrap.dedent("""
    You are ONE worker in a 15-agent diagnostic swarm. Investigate ONLY your
    assigned angle. Read the real files under the project. Be concise.
    Output EXACTLY this format, nothing else:
    CAUSE: <one-line root-cause hypothesis for your angle, or "ruled out: ...">
    EVIDENCE: <file:line refs + 1-2 sentence reasoning>
    FIX: <minimal concrete code change, with file:line>
    CONFIDENCE: <high|medium|low>
""").strip()

ANGLES = [
    ("01-load-trigger", "WHERE/HOW is ListingProvider's load first triggered? Check browse_screen.dart initState and any context.read/Provider.of<ListingProvider>().load() call. On first build, is load() actually called before the first frame, or never (so isLoading stays at its initial value)?"),
    ("02-provider-state", "Read lib/providers/listing_provider.dart fully. What is isLoading's INITIAL value? Does the load method set isLoading=false in a finally/after await? If load throws, does isLoading get reset and notifyListeners() fire? Pinpoint any path where isLoading stays true."),
    ("03-db-init-race", "Examine database_helper.dart _initDatabase web branch (databaseFactoryFfiWeb/OPFS). Can the FIRST call throw or hang while the DB file/worker initializes, with the SECOND (reload) succeeding because state now exists? Look at the `_database ??=` memoization and async ordering."),
    ("04-seed-oncreate", "Does _onCreate/_seedData run reliably on the FIRST web load? On OPFS, is onCreate fired before getListings can query? Could seeding be in-flight/uncommitted when the first SELECT runs, returning 0 rows on first load but committed by reload?"),
    ("05-status-filter", "getListings defaults WHERE l.status='active'. In _seedData, what status value is written to each seeded listing? If seed writes something other than 'active' (or NULL), first query returns 0 rows. Verify the exact status string seeded vs queried."),
    ("06-expiry-filter", "Look at endExpiredAuctions()/end_time logic and whether the home load calls it. Could seeded auctions' end_time be computed such that on first load they're all treated as expired/ended (status flipped) but a reload re-seeds? Check date math in _seedData."),
    ("07-error-swallow", "Find try/catch blocks in listing_provider.dart and listing_repository.dart that swallow exceptions and leave the UI with empty list or stuck loading. Report any catch that doesn't surface the error or reset isLoading."),
    ("08-notifylisteners", "Audit notifyListeners() calls in listing_provider.dart. Is there a missing notifyListeners after the first successful load, so the shimmer never rebuilds even though data arrived? Check Consumer/Selector usage in browse_screen.dart:47 area."),
    ("09-web-vs-native", "Why would FIRST load differ web-vs-native? Focus on async timing: databaseFactoryFfiWeb OPFS init latency vs sqflite native. Is there an unawaited future or a load() that races the DB getter only on the slower web path?"),
    ("10-main-startup", "Read lib/main.dart. Is the DB initialized/seeded BEFORE runApp, or lazily on first query? If lazy, the first frame builds, fires load(), the DB is still creating, and the result resolves but UI isn't refreshed. Map the exact startup ordering."),
    ("11-future-not-awaited", "Hunt for an unawaited Future or a `.then` without setState/notifyListeners in the listing load path (provider + browse_screen). A fire-and-forget load on web (slower) would explain first-load-empty, reload-fixed."),
    ("12-shimmer-exit", "browse_screen.dart:47 returns shimmer while provider.isLoading. Trace EVERY code path that sets isLoading=false. Is there a path (web first load) where none of them execute? Quote the lines."),
    ("13-oldversion-diff", "Compare lib against /home/kopi/projects/yardsale_ja-old for the listing load + db init. Identify any regression: a removed await, a changed default status, a reordered init that would break first-load on web. Report the diff that matters."),
    ("14-reload-delta", "Pin the EXACT difference between first load and reload. After reload the DB OPFS file already exists & is seeded, so _onCreate does NOT run. Does the code path depend on onCreate having ALREADY happened? i.e. first load's load() runs concurrently with onCreate/seed; reload's load() runs against a ready DB. Confirm or refute with file:line."),
    ("15-repro-fix", "Synthesize the single most likely root cause and write the MINIMAL fix as a unified diff: ensure ListingProvider.load() is awaited after DB is ready and isLoading/notifyListeners are correct so the feed populates on FIRST web load without a manual reload. Give the exact file:line edit."),
]

def run_worker(name, angle):
    prompt = f"{RULES}\n\n=== SHARED CONTEXT ===\n{SYMPTOM}\n\n=== YOUR ANGLE ({name}) ===\n{angle}\n\nProject root: {PROJECT}"
    t0 = time.time()
    try:
        r = subprocess.run(
            ["claude", "-p", prompt, "--model", "sonnet"],
            cwd=PROJECT, capture_output=True, text=True, timeout=300,
        )
        out = r.stdout.strip() or f"(no stdout)\nSTDERR:\n{r.stderr.strip()[:500]}"
    except subprocess.TimeoutExpired:
        out = "(worker timed out after 300s)"
    except Exception as e:
        out = f"(worker error: {e})"
    dt = time.time() - t0
    (OUTDIR / f"{name}.txt").write_text(out)
    print(f"[done {dt:5.1f}s] {name}", flush=True)
    return name, out

def main():
    print(f"Launching {len(ANGLES)} headless claude -p workers (concurrency 5)...", flush=True)
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
        futs = [ex.submit(run_worker, n, a) for n, a in ANGLES]
        for f in concurrent.futures.as_completed(futs):
            n, out = f.result()
            results[n] = out
    report = ["# 15-Agent Diagnosis: YardSale JA empty home feed on first load\n"]
    for n, _ in ANGLES:
        report.append(f"\n## {n}\n{results.get(n,'(missing)')}\n")
    (OUTDIR / "REPORT.md").write_text("\n".join(report))
    print(f"\nAll done. Combined report: {OUTDIR/'REPORT.md'}", flush=True)

if __name__ == "__main__":
    main()
