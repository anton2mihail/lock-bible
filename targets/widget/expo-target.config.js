/** @type {import('@bacons/apple-targets/app.config').Config} */
module.exports = {
  type: "widget",
  name: "VerseWidget",
  // Lock-screen accessory widgets require iOS 16. Keep this in sync with the
  // app's minimum iOS version.
  deploymentTarget: "16.1",
  // The App Group is the shared container the app writes preferences to and
  // the widget reads from. Must match app.config.ts and widgetBridge.ts.
  entitlements: {
    "com.apple.security.application-groups": ["group.com.nrsv.verse"],
  },
  frameworks: ["SwiftUI", "WidgetKit"],
}
