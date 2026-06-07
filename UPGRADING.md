# Upgrading from v2 to v3

For most apps, the v2 setup should continue to look very familiar. The main `UpdateCheck` initializer is unchanged, and the basic `SelfUpdater` initializer still accepts the same required arguments:

```swift
let delegate = SelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    selfUpdaterPath: "~/.config/com.example.my-app/updater"
)
```

## What Changed

The downloader no longer shells out to `curl`. v3 uses `URLSession` for downloads, while keeping the shell-backed filesystem path for extraction, moving the app into `/Applications`, and checksum validation.

The update flow is also a little safer:

1. The update archive is downloaded.
2. The SHA-256 checksum is validated.
3. The archive is extracted into the updater directory.
4. The extracted app bundle is validated.
5. The running app is asked to quit.
6. The updater waits briefly for the app to terminate.
7. The app is replaced in `/Applications` and relaunched.

This means the installed app is no longer terminated before extraction succeeds.

## Translation API

If you customized alert text in v2, update references from lowercase `translations` to `Translations`:

```swift
// v2
UpdateCheck.translations.buttonInstall = "Upgrade"

// v3
UpdateCheck.Translations.buttonInstall = "Upgrade"
```

The same applies to self-updater text:

```swift
SelfUpdater.Translations.progressWindowTitle = "Updating %@"
```

v3 also exposes more updater strings for localization, including download failures, checksum validation failures, extraction failures, termination failures, and the progress byte-count format.

## Progress Window

The self-updater now has a progress window. By default, it only appears when the update takes longer than 3 seconds:

```swift
progressWindowDisplayMode: .whenUpdatingTakesLongerThan(3)
```

To always show it:

```swift
let delegate = SelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    selfUpdaterPath: "~/.config/com.example.my-app/updater",
    progressWindowDisplayMode: .always
)
```

You can also pass `downloadProgressImage` to display a custom image in the progress window.

## Download Timeout

Downloads have a hard timeout. By default this is 15 minutes, but you can override it on the self-updater delegate:

```swift
delegate.downloadHardTimeout = 30 * 60
```

## Manifest Format

No manifest changes are required when upgrading from v2 to v3. The package still reads the same Homebrew-style Cask file and still uses the same local `update.json` handoff between the main app and the self-updater.
