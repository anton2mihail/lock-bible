# Reader proof prototype

This project records the accepted L01 reader and tab mechanisms. It is a prototype. It uses Swift 5. The production app uses Swift 6.

The project uses local sample files from `Resources/`. The script creates these files from the Bible and Works sources. It also writes `Resources/manifest.json` with source and sample hashes. Run it from the repository root:

```sh
node native/Prototypes/ReaderProof/prepare-samples.mjs
xcodebuild -project native/Prototypes/ReaderProof/ReaderProof.xcodeproj -scheme ReaderProof -configuration Debug -destination "platform=iOS Simulator,id=37D1870B-F16D-488A-8F20-959201F970D9" -derivedDataPath build/native-evidence/L01/renderer-proof/DerivedData build
```

The accepted simulator evidence is in `build/native-evidence/L01/renderer-proof/`. The accepted page-fit capture is `03-works-page-2.png`. The shell comparison is `04-shell-comparison.png`. The selected reader captures are `05-john-selected-large.png` and `06-john-selected-xl.png`. The blank `01-reader-john.png` remains a failed capture. It is not evidence of reader content.

The proof does not close full reader parity. Production tests still need the remaining layout, selection, accessibility, storage, and device checks.
