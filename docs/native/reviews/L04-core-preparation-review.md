# L04 Core preparation review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: ACCEPTED bounded package at commit `2aaef1d67c28d54ec0841feb83d6029f01cfcf51`. Full L04 remains open.

## Reviewed scope

Sol read the package manifest, domain types, Bible repository, Works repository, indexed rotation repository, SQLite helpers, library boundary, and integration guide.

The package uses Swift 6 and system SQLite/zlib. Bible loading is lazy by book. The only Bible cache contains edition metadata and manifests. Works browsing reads a small catalog. A section request reads one database row with a bound work ID and index. Decoded BLOB and TEXT content has a 400,000-byte limit.

The indexed rotation reader maps the corpus and decodes one selected record. It validates index sizes, offset endpoints, bounds, ordered scope maps, complete scope coverage, and separate OT/NT membership. It preserves source record order.

SQLite handles stay inside repository actors. Statements retain their connection and finalize on release. The library boundary checks the existing schema and makes a new consistent backup. It does not create a missing library or write library rows.

## Reviewed fixes

1. `RotationResourceRoot` selects the app's `Rotation` directory or the widget's flat directory. Both use the same parser.
2. `ContinuousClock` supplies the five-second backup deadline. The API and README describe partial backup files and unique retry paths.

Host and iOS Simulator SDK build logs and a package source hash manifest are saved under `build/native-evidence/L04/core-preparation/`. Both logs report successful builds. SDK compilation is preliminary evidence. Main Luna must run the package in the app before L04 acceptance.

## Later acceptance conditions

L04 still requires typed state normalization, the atomic state envelope, a read-only MMKV adapter, library operations, and interrupted same-ID simulator migration. Search behavior retains its source parser and ordering requirements. Widget integration must use this same rotation reader.

Runtime content checks must compare the staged resources and canonical source files. A successful package build does not prove content parity or update safety.
