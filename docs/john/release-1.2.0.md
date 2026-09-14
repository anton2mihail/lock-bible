# John 1:1 1.2.0 (13)

Production iOS build completed on September 9, 2026.

- Build: https://expo.dev/accounts/antonmihail/projects/NRSV/builds/44d60c36-2a69-446a-b788-acb23a696462
- Submission: https://expo.dev/accounts/antonmihail/projects/NRSV/submissions/287e4042-a39b-438f-b576-6ed8b08ac6ec
- App Store Connect app: 6784763639
- Submission state: FINISHED (confirmed September 10, 2026). EAS completed the upload to App Store Connect.

The release uses Bun 1.3.14 and the existing app/widget signing credentials.
`withLocalNotificationsOnly` removes Expo’s automatic APNs entitlement because
calendar and Rosary reminders are local notifications. The plugin runs after
the notification entitlement mod; the app group is preserved. Revisit this
plugin before implementing remote push notifications.

No App Store review or public release was requested through the submission job.
