# Rosary source session fixture

This fixture calls the current Rosary catalog and session builders. It exports the four mystery sessions and the Seven Sorrows session. It includes exact step IDs, group labels, prayer text, repetition counts, scripture references, and instructions.

Run from the repository root:

```sh
bun scripts/native/source-fixtures/content/rosary-session-fixtures.ts build/native-evidence/L10-L11/rosary-session-fixtures.json
```

The fixture records a temporary progress trace for every session. It includes the start state, a repeated-prayer forward/back sequence, every action through completion, back from the completion screen, and the “Pray again” reset. The guide screen uses React state for this progress. It does not save this step progress. The transition trace reconstructs the screen callbacks because the source screen does not export them as functions.

The fixture records the guide's missing/invalid set fallback on a fixed local Monday. It records the media screen's missing/invalid episode fallback to the first catalog episode. It records the release gate `__DEV__ || hasApprovedRosaryMedia(episode)`, approval metadata, and official episode links. It does not open or fetch media.

The output records SHA-256 hashes for the catalog, session builder, types, source tests, guide screen, media screen, and generator. I ran the generator twice. Both outputs had SHA-256 `8da3d86f5bb284a197188e69292ef1f3b5507b51229c5bc5dc6c9ca97bdb2dee`. It is source evidence. It is not simulator evidence. Keep the generated JSON in ignored `build/native-evidence/L10-L11/`.

## Main simulator handoff

Compare native session IDs, titles, group labels, steps, and prayer values with `sessions[*].session`. Check the progress traces against the screen's temporary state behavior. Check the source Monday fallback. Check the media gate and first-episode fallback without starting a player. Keep progress temporary unless the approved native contract says otherwise.
