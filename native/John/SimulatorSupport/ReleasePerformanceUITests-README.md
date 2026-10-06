# L26 Release performance UI checks

Main owns target membership, the Release build, the task-only seed, network isolation, resource tools, and every simulator run. This file defines measurements only. It does not add app instrumentation.

Set these test-run environment values before the run:

- `L26_RELEASE_BUNDLE_ID`: explicit task-only Release app bundle ID. Do not use the preserved production update fixture.
- `L26_TASK_SEED_ID`: identity of the task-only development seed.
- `L26_BUILD_CONFIGURATION`: `Release`.
- `L26_APP_BINARY_SHA256`: SHA-256 of the app binary used by the run.
- `L26_SEED_TRANSLATION_ID`: `web-ce`.
- `L26_SEED_HAS_WORKS_POSITION`: `false`.
- `L26_SAMPLE_COUNT`: `3` for setup preflight or `20` for the recorded distribution.

The helper stops before measurement when the bundle, seed, WEB-CE identity, no-saved-Works-position condition, Release configuration, binary hash, or sample count is missing. The Search and Reader actions use real controls. They return through Reader Back controls when the app restores a prior Reader location. The Works journey starts at the first section and therefore needs no saved Works position. Main must provide a fresh, valid synthetic seed. Main must isolate network access before the run. The test does not change network settings or seed data.

The launch method terminates and launches the app process for each sample. “Cold” means a new app process. It does not mean a cold OS or file cache. The timer uses `ProcessInfo.processInfo.systemUptime`. Launch readiness requires the Today title, a loaded readings card, a current prayer action, and nonempty verse text. The log records each observed label and whether the verse is hittable. Loaded verse data and visible verse placement are separate facts.

The chapter and Search method performs one excluded warm-up for each workload. It then records the configured sample count. Chapter timing begins before the chapter 1 tap. It ends after the exact John 1 title, canonical John 1:1 text, and edition attribution are present. Search timing begins before query replacement and typing. It ends when the exact final query has its expected result. The Search result uses John 3:16 and the L09 “faith” full-text query. These values measure user action, typing, debounce, and accessibility polling. They do not measure repository or decode time.

The long-text method captures one later verse in Psalm 119 and the first two pages of Chrysostom, *Homilies on the Gospel of John*, Homily 10. It checks a real verse control, page markers, and changed page text. These captures do not measure frame rate.

Each summary logs raw samples, the median, and empirical nearest-rank p95. Three-sample output is preflight only. Twenty samples provide the recorded simulator distribution. A 30-second timeout detects a failed readiness path. It is not a performance limit. The proposed 1-second median, 1.5-second p95, and 150-millisecond query targets remain physical-device proposals. Do not apply them as simulator acceptance limits.

For the run record, Main must add the simulator model and runtime, toolchain, app and widget binary hashes, actual date and time zone, seed identity, launch PIDs, host load, and network isolation method. Keep migration separate from these workloads.

For resource records, report named process IDs, current resident footprint, and timestamps. RSS is host-process resident memory. It does not prove device peak memory. Report the widget extension separately from the app. Do not sum shared RSS. Report app bundle bytes, app/container data, extension bytes, duplicate corpora, and caches as separate values. Simulator values do not prove archive size or physical-device limits.

The helper does not repeat storage damage, recovery, migration, Rosary, or temporary-state journeys. Those checks remain in their accepted test scopes.
