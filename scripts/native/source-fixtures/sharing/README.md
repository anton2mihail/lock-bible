# Scripture card export capture

The UI test `testLongSelectedPassageExportsIvoryPlumAndRepeatAfterCancel` exports three PNGs in this order: ivory, plum, then plum-repeat. Start the watcher before the test launches the app. Wait for its `CONTAINER_READY` record before you start the test. This lets the watcher take a baseline before the first export tap. It resolves the data container again while it runs, so it can follow an app reinstall. Do not use a production app container.

```sh
python3 scripts/native/source-fixtures/sharing/watch-scripture-card-pngs.py \
  --udid 37D1870B-F16D-488A-8F20-959201F970D9 \
  --bundle-id com.nrsv.verse.dev \
  --evidence-dir build/native-evidence/L25/functional/card-png-watch-r1/pngs \
  --labels ivory plum plum-repeat \
  --timeout-seconds 300
```

The watcher records `ARMED` when it starts and `CONTAINER_READY` after it resolves the simulator container and scans its initial file list. Wait for `CONTAINER_READY` before the test starts. It then copies each stable new PNG as soon as it appears. It assigns labels by arrival order and stops after all labels arrive. The evidence directory must be new. The manifest records the source filename, SHA-256, byte count, pixel dimensions, and UTC times. It checks that the source stayed stable and that copied bytes match. If the app is reinstalled, the watcher follows the new container and treats its PNGs as new candidates.

The watcher runs for at most ten minutes. Its default timeout is five minutes. It returns an error if it captures fewer files than the label list. It does not delete or modify app files. It records no full app-container path. Keep the share panel open until the matching `CAPTURED` record appears. Then complete or cancel the panel as the test requires.

Main must inspect each copied PNG for the full Psalm 2:1–12 text, reference, edition, and selected colors. Main must also verify that the app removes the temporary PNG after share completion or cancellation.

For long text, the UI journey selects bundled WEB-CE Psalms 2:1–12. The source text joined with one space has 1,043 UTF-16 code units. The test enters through Settings, Reader book/chapter/verse controls, and the card action. It checks the first and last verse text, `Psalms 2:1–12`, and `WEB-CE` in the preview. The test does not claim that the pixels match. Pixel inspection uses the copied PNGs.

`testLongCardSharePresentationOnIPadWhereSupported` records the observed native share surface and checks a visible Copy action, route survival after dismissal, and no test-process failure. It does not require an iPad popover or sheet in advance.
