# Android privacy and Play Console disclosures

Prepared: 2026-10-13. These are source-based drafts. No Play Console form has been submitted by this document.

Release identity: John 1:1, `com.john.bible`, version 1.0.0 / 1. The user confirmed a new app in an organization account. The app is free, with no ads or purchases. Public support: `contact@north.boutique`.

## Public policy

Source: [`site/privacy.html`](../../site/privacy.html).

Public URL: <https://anton2mihail.github.io/lock-bible/privacy.html>. The repository's GitHub Pages API returned <https://anton2mihail.github.io/lock-bible/> on 2026-10-13. The new policy was deployed on 2026-10-13 in commit `48425a2`. An HTTP check returned 200 and confirmed the new John policy text. Publisher: North Boutique Studios Ltd. The account owner confirmed this organization.

The new policy covers both native platforms. iOS sync is described only where its setting is available. The current iOS `Info.plist` sets `JohnCloudSyncAvailable` to false. Its optional sync implementation uses a private CloudKit database and is off by default. Android has no John account or app-operated sync server.

## Source review

| Feature | Actual data use | Source |
| --- | --- | --- |
| Local user data | Private shared preferences contain notes, drawings, tags, saved passages, recent searches, reading position/progress, favorite prayers, novena intentions/progress, reflections, and settings. | `native/Android/app/src/main/java/com/john/bible/data/JohnStore.kt` |
| Device backup | Source verified: `allowBackup=false`. Android 8–11 backup rules exclude root, file, database, sharedpref, and external data. Android 12+ rules exclude these domains in both cloud backup and device transfer. No device-protected user storage is created. The bundled databases use `noBackupFilesDir`. The merged release manifest check is recorded below. | `AndroidManifest.xml`, `res/xml/backup_rules.xml`, `res/xml/data_extraction_rules.xml`, `data/JohnRepository.kt` |
| Dictation | `ACTION_RECOGNIZE_SPEECH` opens a separate recognition activity. John does not record audio itself. Returned transcript text enters the local note editor. Source verified: Dictate opens a provider notice. Only Continue launches recognition; Cancel does not. `EXTRA_PREFER_OFFLINE=true` is a preference, not an offline guarantee. | `ui/NoteEditor.kt` |
| Read aloud | Android `TextToSpeech` receives the selected Scripture verse. Source verified: every playback call selects a voice with `isNetworkConnectionRequired=false` and no `notInstalled` feature. No suitable voice or failed `setVoice` stops playback with an install-voice message. Settings apply the same filters. No network/default-language fallback remains. | `ui/ReaderScreens.kt`, `ui/SettingsScreens.kt` |
| Export/import | A system file picker selects one document. Export writes notes, tags, saved passages and drawings to the selected URI. Import reads a selected JSON document. The selected provider can be cloud storage. | `ui/LibraryScreens.kt`, `data/JohnStore.kt` |
| Share | The user selects a target app in the Android Sharesheet. Selected text or generated Scripture card is passed to that app. No developer upload occurs. Temporary images use a private FileProvider with a URI read grant. | `ui/ReaderScreens.kt`, `ui/PlatformScreens.kt`, `platform/ScriptureShare.kt` |
| External sources | Official readings and Rosary links open a browser or another app. The pinned Android catalog has no approved direct audio/video URLs. Release therefore links to the official Rosary videos. | `data/JohnRepository.kt`, `ui/DevotionalScreens.kt`, `native/Android/content/companion.json` |
| Confession guide | Notes remain in memory. They clear when the guide closes or the app enters the background. They do not enter shared preferences or saved-state storage. | `ui/DevotionalScreens.kt`, `ConfessionGuide` |
| Reminders | Local Android scheduling. Notification permission is requested when enabling reminders. Reboot/time-change receiver reschedules reminders. | `platform/JohnReminders.kt`, `ui/PlatformScreens.kt` |
| Background read aloud | A foreground service with `mediaPlayback` keeps user-started Scripture speech active. Media notification controls include Pause/Play, previous/next, and Stop. | `platform/JohnPlaybackService.kt`, `MainActivity.kt`, `AndroidManifest.xml` |
| Third-party app libraries | The resolved release list contains AndroidX, Kotlin, Guava listenablefuture, and annotation libraries. No advertising, analytics, or crash-upload SDK appears in that list. Package evidence is recorded below. | `app/build.gradle.kts` |

## Data Safety draft

Release choice: exclude Android automatic cloud backup and device transfer. Keep explicit manual export/import. Require an installed offline TTS voice. Explain the separate dictation provider before launch. The public policy reflects this release choice.

The required code changes are present and independently reviewed. Package evidence is recorded below. These answers remain drafts; this document does not confirm runtime checks or completed Play Console forms. Do not use them for the earlier build that enabled automatic backup and a possible network TTS voice.

| Form question | Draft answer | Basis |
| --- | --- | --- |
| Does the app collect or share required user data types? | No | John saves user data locally. It has no developer upload, telemetry, automatic cloud backup, or online TTS path. Explicit transfers below have separate user-selected service boundaries. |
| Does the app create user accounts? | No | No John account creation, login, or authentication. External provider accounts are separate. |
| Data types collected | None | Notes, drawings, reflections, intentions, recent searches, and reading progress are processed locally by John. |
| Data types shared | None reportable in this draft | The user chooses whether to share selected content, export a file, or open the separate dictation provider. Apply the user-action sharing exception to the documented flows below. |
| All collected data encrypted in transit | Not applicable when the form skips it | No app-operated off-device collection. Do not claim that every external provider uses encryption. |
| Data deletion request mechanism | Do not assert a remote app-account deletion feature | There is no John account or server copy. Local deletion and Clear storage are described in the policy. Support can handle information sent directly by email. |
| Independent security review | No | No qualifying review has been established. |
| Families commitment badge | Leave unselected | Target audience and Families scope require the actual questionnaire. |

### Rationale

Google defines collection as data sent off the device. Local processing is outside that scope. A user-directed transfer can be exempt from the sharing answer when sharing is expected. This exception alone does not exempt collection. The system-service exemption applies to qualifying preinstalled services, not every app that calls one. [Google Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

The “No” draft follows the final app boundary, rather than claiming that outside services collect no data:

- **Notes and activity:** John stores them in private local preferences. Backup exclusions prevent an automatic app-data upload. These data can include personal or religious information, but do not become reportable collection while processed locally.
- **Dictation:** The user sees the notice and chooses Continue. A separate recognition app then records audio directly under its own provider rules. John supplies no recorded audio and receives the returned transcript locally. This is an external activity, not an embedded speech SDK. A provider can use a server. Do not describe that provider as offline or imply that its records are controlled by North Boutique.
- **Read aloud:** Only installed offline TTS voices are selected. Network voices must not be used as a fallback. The setting and runtime code must enforce the same rule.
- **Share:** The user selects a target app in the Android Sharesheet. The selected text or Scripture image is visible and expected. This explicit transfer fits the user-action sharing exception. John does not upload a copy.
- **Export:** The user selects the document location in a system picker. The document can contain notes and drawings. The selected storage provider handles its own storage and possible cloud upload. John writes only to the user-selected URI and has no storage-provider API or automatic upload. Do not generalize this reasoning to automatic cloud backup.
- **External links:** The release opens a browser or another app. The current catalog contains no approved direct online media URLs. John has no controlled WebView that sends notes or reading history to those sites.
- **Support email:** The user can send email outside the app. North Boutique receives the address and message supplied by that user. The policy explains this; it does not claim that the organization never receives personal information.

Review this draft again if an embedded cloud recognizer, network speech voice, direct media URL, telemetry SDK, account, or automatic backup is added. The dormant approved-media player calls `prepareAsync` when its screen opens. Adding remote media can therefore change data flows before Play is pressed.

### Required package checks

1. Confirm `allowBackup=false` in the merged release manifest.
2. Confirm explicit cloud-backup and device-transfer exclusions cover every applicable data domain.
3. Confirm Android 8–11 backup rules also exclude saved preferences and files. Android minimum API is 26.
4. Confirm playback stops with an install-voice message when an offline voice is unavailable.
5. Confirm the dictation provider notice appears before the external recognition activity.
6. Confirm the policy link opens the deployed page from release Settings.
7. Confirm resolved release dependencies contain no telemetry or other collection SDK.
8. Confirm all release Rosary entries have no direct `audioUri` or `videoUri`.

These are release checks, not evidence that the final bundle has already passed. Android backup behavior can differ by version and manufacturer; use both the manifest and the explicit extraction exclusions. [Android Auto Backup](https://developer.android.com/identity/data/autobackup)

## Independent source verification

Reviewed the changed source on 2026-10-13. Source checks pass for the manifest, both backup XML files, the only TTS `speak` path, settings voice filters, Dictate/Continue/Cancel, and the Settings policy URL. The policy URL in code is <https://anton2mihail.github.io/lock-bible/privacy.html>. The catalog still contains no direct Rosary audio/video URI entries.

The no-backup source rules cover every data domain currently used by the app. Source search found no `createDeviceProtectedStorageContext`, direct speech/audio capture, or additional TTS call path. If device-protected storage is added, include its device-prefixed XML domains as well.

This review did not run Gradle or install the app. Existing release outputs and the public policy were checked separately below. Actual device/provider behavior, the foreground-service video, and completed store forms remain with the main release task. No new privacy mismatch was found in the reviewed source.

## Independent release-output verification

Checked existing release outputs on 2026-10-13 without running Gradle:

- The merged release manifest identifies `com.john.bible`, version code 1, minimum API 26, and target API 36. It retains `allowBackup=false` and the backup-rule references.
- Its six permissions are Internet, foreground service, media playback foreground service, notifications, boot reception, and the app's signature-protected receiver permission. It has no advertising ID, location, contacts, microphone recording, camera, or full-screen intent permission.
- The resolved release dependency XML contains AndroidX and Kotlin libraries, Guava `listenablefuture`, and annotation libraries. No advertising, analytics, or crash-upload SDK appears in that resolved list. The startup components in the merged manifest are AndroidX components.
- `app-release.aab` contains `base/assets/Catalogs/devotional-catalogs.json`. Its bytes exactly match the pinned Android catalog. It contains 7 novenas, 28 prayers, 5 teachings, and no approved direct Rosary media URL.
- The bundle contains `META-INF/JOHN-UPL.SF` and `META-INF/JOHN-UPL.RSA`. Signing metadata reports a signed release. These observations do not replace the release verifier's cryptographic signature check.

Catalog SHA-256: `4da66b092ff01d3dd7897425e17ad46cb5d82cf82716946e0e867eb8cfcec484`.

The public privacy URL returned HTTP 200. Its bytes matched `site/privacy.html` in deployed commit `48425a2` exactly. Policy SHA-256: `51ca5b04f237672ea7b187479a937ab913ef8284858f43079dcdb46925b6e2db`. This confirms the website content. It does not confirm that the link has been opened on a release device or that any store form is complete.

## Clean-source staging proof

Ran Android staging in a separate temporary directory on 2026-10-13. No Gradle command ran. Shared source files and existing build outputs were not changed.

The staging audit checked every normal repository input against the Git blob in HEAD `48425a2b00e9cbd312916ff6a32dbe56cef661b6`. All 334 shared input files matched HEAD. The only new repository content inputs were `native/Android/content/companion.json` and `companion-provenance.json`. Nine font/license files came from the installed font packages. `package.json` and `bun.lock` also matched HEAD.

The stage script did not read or execute any shared TypeScript file. It used the pinned catalog. Provenance source hashes are records, not staging conditions. The separate refresh helper is not part of normal builds.

The temporary stage produced 352 files. Full asset verification passed for all 106,999 verses and all 16,146 Works sections. The staged catalog retained the exact SHA-256 shown above. Hashes of the recorded shared source files were unchanged before and after this proof. Temporary staging output was removed.

This proves that normal staging no longer depends on the uncommitted shared TypeScript edits. It uses existing HEAD content plus the new reviewed Android inputs. It does not replace a full build from a clean checkout or a fresh dependency installation.

## Other Play Console content drafts

| Item | Draft |
| --- | --- |
| App access | All features are available without a John account or login. No review credentials are required. Installed speech service/voices are required for dictation/read aloud. A network connection is required to open external websites. |
| Ads | No ads. |
| Price | Free. |
| In-app purchases | None. |
| Advertising ID | No advertising ID use found. Confirm the merged release manifest has no `com.google.android.gms.permission.AD_ID`. |
| Financial features | None found. |
| Health features | No health feature or Health Connect use found. Prayer and reflection are religious features. |
| User communication | No app-operated messaging, public posts, profiles, or user-to-user service. Private notes remain personal content. The Android Sharesheet can send selected content to another app. |
| Location | No location permission or location API use found. External service network requests can reveal network addresses. |
| Notification use | Local reading, calendar, and Rosary reminders. Notification permission is optional. Media controls support user-started read aloud. |
| Full-screen intent | Not used. No `USE_FULL_SCREEN_INTENT` permission declared. |
| AI content | Static commissioned illustrations are included. The app does not generate prayers, answers, text, or images in response to a user prompt. |
| Target audience/content rating | Complete the actual questionnaire. The full Bible and historical writings can discuss violence, death, sexuality, and other mature topics. Do not prefill “no violence” or a specific rating without reviewing its wording. |

## Foreground service declaration

Type: `mediaPlayback`. Permission: `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`. Use case: Media playback. This declaration covers Scripture read aloud. Current direct Rosary audio playback does not run in this service.

Suggested feature description:

> The user starts Scripture read aloud in the Bible reader. John 1:1 uses the device's text-to-speech service. The media playback foreground service keeps the selected chapter audible when the user leaves the app. A media notification shows the passage and provides playback controls. The user can pause or stop playback at any time.

Suggested interruption impact:

> If playback starts late, the user does not hear the passage after pressing Play. If the service stops while reading, the chapter stops before completion. This interrupts the user-requested listening session. The service is active only for that session.

Record a real release build. Use this video sequence:

1. Open John 1:1.
2. Open the Bible reader.
3. Select John 1.
4. Press Play to start read aloud.
5. Leave the app with the Home button.
6. Keep the audio audible in the recording.
7. Open the notification panel.
8. Show the passage and playback controls.
9. Press Pause.
10. Press Play.
11. Press Stop.
12. Show that playback and the notification stop.

Video status: not recorded or hosted by this draft. Add a review-accessible video URL to the actual form. Do not insert a placeholder URL. Google requires the feature description, interruption impact, use case, and demonstration video. [Foreground service declaration requirements](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en)

## Checks before submission

1. Deploy the policy and confirm the public URL returns the new John 1:1 page.
2. Open the policy from Android Settings in the release build.
3. Match the Data Safety answers to the final backup, TTS, dictation, and media behavior.
4. Review the resolved release dependencies and merged manifest.
5. Confirm the publisher name and support contact in Play Console.
6. Record and host the foreground-service video.
7. Complete the target audience and content rating forms from their exact wording.
8. Review the Play listing preview before submitting each declaration.
