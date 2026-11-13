## Moment 1.2.0

Keep a countdown visible with a Live Activity on the Lock Screen and Dynamic Island during the final eight hours before an event. Share a vertical 9:16 event card, search event titles and notes, and create custom reminders up to 180 days ahead. iOS controls Live Activity display time and may end it earlier.

This release also includes English localization, clearer widget setup, annual events, progress indicators, and JSON backup export/import.

### Install

Install `Moment-1.2.0.ipa` with Sideloadly over the previous version. Existing saved events are preserved. Choose the app language in **Settings → Apps → Moment → Language**; System uses the iPhone's preferred language.

For the widget, touch and hold it and choose **Edit Widget → Setup → Manual**. Selecting events saved in the app requires App Groups for both the app and widget.

Open an event up to eight hours before it is due and tap **Show Live Activity**. If Live Activities are disabled, allow them in **Settings → Apps → Moment → Live Activities**. Add custom notification intervals from the event editor's **Custom reminders** section.

Use the **…** menu on the home screen to export events as JSON or import a backup. Import adds event IDs that are not already present and keeps current events intact. Event details can share a text countdown or a vertical image card.

### Build

The unsigned arm64 IPA is built with Xcode 16.4; minimum supported version is iOS 17.0. This release workflow builds the archive without running simulator tests.

SHA-256 IPA: `pending`
