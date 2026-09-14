# John 1:1 1.2.2 (15)

Resubmission after App Review rejected 1.2 (13) on September 11, 2026
(submission 816b627b-c4ea-4b4b-9a58-75c8435f6293):

- Guideline 2.5.4: the app declared the `audio` background mode without
  playing audible content in the background. `enableBackgroundPlayback` and
  `supportsPictureInPicture` are now off, so `UIBackgroundModes` is empty.
  Re-enable both only once the Rosary media screen ships real audio and a
  screen recording of background playback can be attached to the review notes.
- Guideline 2.3.8: the App Store name ("Lock Bible") and the on-device name
  ("John 1:1") did not match. The App Store name was changed in App Store
  Connect so it contains the device name; the bundle identifier is unchanged.

Also in this build: iOS 18 dark and tinted app icons, a splash screen that no
longer shows the square icon tile, a safe-zone Android adaptive icon with a
monochrome layer, refreshed App Store screenshots for the five-tab app, and
removal of the unused Ignite welcome screen and legacy icon assets.
