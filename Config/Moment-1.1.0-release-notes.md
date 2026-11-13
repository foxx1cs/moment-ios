## Moment 1.1.0

Moment now includes an English interface, clearer widget setup instructions, local event reminders, annual recurring events, event sharing, progress indicators, and JSON backup export/import. February 29 recurrences use February 28 in non-leap years.

### Install

Install `Moment-1.1.0.ipa` with Sideloadly over the previous version. Existing saved events are preserved. Choose the app language in **Settings → Apps → Moment → Language**; System uses the iPhone's preferred language.

For the widget, touch and hold it and choose **Edit Widget → Setup → Manual**. Enter the title, date, time, and seconds. Selecting events from the app requires a provisioning profile with App Groups enabled for both the app and widget.

To enable reminders, open an event, choose one or more options under **Reminders**, and save. iOS asks for notification permission the first time. Delivery follows the iPhone's notification and Focus settings. Enable **Repeat every year** for birthdays and other annual dates.

Use the **…** menu on the home screen to export events as a JSON file or import a backup. Import adds events whose IDs are not already present and keeps current events intact. Event details include a share action with the current countdown.

### Build

The unsigned arm64 IPA is built with Xcode 16.4; minimum supported version is iOS 17.0. This release workflow builds the archive without running simulator tests.

SHA-256 IPA: `pending`
