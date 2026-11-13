## Moment 1.3.0

Annual reminders now use the actual date for each occurrence, including February 29. Reminder updates are serialized, the schedule is replenished when the app opens, and tapping a notification opens its event. You can duplicate an event from its detail screen and edit the copy before saving.

iOS permits up to 64 pending notifications. Moment schedules the closest reminders and up to five upcoming annual occurrences, and refreshes the schedule when opened. Notification delivery follows iOS notification and Focus settings.

Install `Moment-1.3.0.ipa` using Sideloadly over the existing app. Keep the widget extension enabled during installation. Minimum iOS version is 17.0.

The release workflow builds an unsigned arm64 IPA and runs focused simulator checks for reminder planning. See the workflow run for results.

SHA-256 IPA: `pending`
