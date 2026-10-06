# Scripture card export capture

The UI test `testLongSelectedPassageExportsIvoryPlumAndRepeatAfterCancel` prints `CARD_PNG_ARM` and waits for 8 seconds before each export tap. Start one watcher for that label before the export tap. Wait for its flushed `READY` record. The watcher then waits for the new PNG while the native share panel remains open for 12 seconds. Use the app's temporary directory from the task-only development container. Do not use a production app container.

```sh
python3 scripts/native/source-fixtures/sharing/capture-new-scripture-card-png.py \
  --source-dir "$APP_TMP_DIR" \
  --evidence-dir build/native-evidence/sharing/card-ivory \
  --label ivory
```

Run three watcher processes in sequence. Match their labels and new evidence directories to the test markers: `ivory`, `plum`, then `plum-repeat`. Start each process before its matching export tap and wait for `READY`. Each output directory must be new. The watcher records only a PNG that appears after its baseline. It records the new file name, SHA-256, byte count, pixel dimensions, and UTC capture time. It also checks that the source did not change during the copy.

The watcher copies one new `john-scripture-card-*.png` file. It records no full sandbox path. It does not delete or modify the app file. Keep the share panel open while the watcher runs. Main must inspect each copied PNG for the full Psalm 2:1–12 text, reference, edition, and selected colors. Main must also verify that the app removes the temporary PNG after share completion or cancellation.

For long text, the UI journey selects bundled WEB-CE Psalms 2:1–12. The source text joined with one space has 1,043 UTF-16 code units. The test enters through Settings, Reader book/chapter/verse controls, and the card action. It checks the first and last verse text, `Psalms 2:1–12`, and `WEB-CE` in the preview. The test does not claim that the pixels match. Pixel inspection uses the copied PNGs.

`testLongCardSharePresentationOnIPadWhereSupported` records the observed native share surface and checks a visible Copy action, route survival after dismissal, and no test-process failure. It does not require an iPad popover or sheet in advance.
