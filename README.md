# AppUpdater Package

## What this does

This is a package that helps you build a self-updater for a given macOS application. It is currently based on code for PHP Monitor.

This package contains code that can be used for the self-updater app that you can ship with your app, and code that you can use in your main app.

Your app must ship the self-updater as a separate sub-app, so that it can be launched independently from the main executable, which is terminated upon launching the sub-app.

Here's how it works:

- The updater checks if a newer manifest file is available. If there is, it is downloaded to the `UpdaterPath`.

- If the user chooses to install the update, the main app is terminated once the self-updater app has launched.

- The self-updater will download the .zip file and validate it using the checksum provided in the manifest file. If the checksum is valid, the app is (re)placed in `/Applications` and finally launched.

## Example

As a separate target (for a macOS app), you need to add the following file:

```swift
import Cocoa
import AppUpdater

let delegate = AppSelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    baseUpdaterPath: "~/.config/com.example.my-app/updater"
)

NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
```
