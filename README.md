# NVAppUpdater Package

## What is this?

This is a package that helps you build a self-updater for a given macOS application. It is supposed to act as an alternative to [Sparkle](https://sparkle-project.org/). 

This was originally written as part of my "zero non first-party dependencies" policy for PHP Monitor, where [the original code](https://github.com/nicoverbruggen/phpmon/tree/641328760684472a9a3c6191d15dcab249d92271/phpmon-updater) has been responsible for serving updates for many users over the last few years.

This package contains code that can be used to ship a self-updater app that you can ship alongside your app, with code that you can use in your main app.

Your app must ship the self-updater as a separate sub-app, so that it can be launched independently from the main executable, which is terminated upon launching the sub-app.

## How does it work?

Here's how it works:

- From within the main app, you can perform a so-called `UpdateCheck`. This will connect to a URL of your choice where you have made a manifest file available. That manifest file is then checked and compared to the current version.

- If the version specified in the manifest file is newer, then the user will see a message prompting them to update the app. If the user chooses to update to the newer version, details of the upgrade URL and checksum are written to a temporary file as a JSON file.

- If the user chooses to install the update, the main app is terminated once the self-updater app has launched. To do this, you must specify the correct bundle ID(s) in the self-updater, or the app won't be terminated.

- The self-updater will download the .zip file and validate it using the checksum provided in the manifest file. If the checksum is valid, the app is (re)placed in `/Applications` and finally (re-)launched.

## Checking for updates

### Requirements

To check for updates in your main target you need to meet a few conditions:

1. You must have a self-updater app that can be executed separately. You must build and embed this app as part of the main target. It's relatively easy to do this, see the *Self-Updater* section below for instructions on how to make the self-updater work correctly.

2. You must declare where the temporary directory is for the updater.

3. You must have a CaskFile and zip hosted which will both be downloaded and checked if the user searches for updates.

### Making a manifest file

AppUpdater uses the same format Cask files for Homebrew use. A valid CaskFile looks like this, for example:

```
cask 'my-app' do
  version '1.0_95'
  sha256 '1b39bf7977120222e5bea2c35414f76d1bb39a882334488642e1d4e87a48c874'

  url 'https://my-app.test/latest/app.zip'
  name 'My App'
  homepage 'https://myapp.test'

  app 'My App.app'
end
```

You must calculate the SHA-256 hash of the .zip file, since that will be validated. The app will also look at the version number to compare to the installed version. 

The version number uses the following format: VERSION_BUILD. (So for this example we are looking at a manifest of My App, version 1.0, build 95.)

You must always place the CaskFile at the same URL, and you will specify where to find this file via the `caskUrl` parameter as part of searching for updates.

### How to perform an update check

To check for updates, simply create a new `UpdateCheck` instance with the correct configuration, and call `perform()`:

```swift
import NVAppUpdater

await UpdateCheck(
    selfUpdaterName: "MyApp Self-Updater.app",
    selfUpdaterPath: "~/.config/com.example.my-app/updater",
    caskUrl: URL(string: "https://my-app.test/latest/build.rb")!,
    isInteractive: true,
).perform()
```

You can also specify what callback needs to be used to determine the correct URL for the release notes. You may need to get some information from the CaskFile, which you are free to source. For example:

```swift
import NVAppUpdater

await UpdateCheck(
    selfUpdaterName: "MyApp Self-Updater.app",
    selfUpdaterPath: "~/.config/com.example.my-app/updater",
    caskUrl: URL(string: "https://my-app.test/latest/build.rb")!,
    isInteractive: true,
)
.resolvingReleaseNotes(with: { caskFile in
    return URL(string: "https://my-app.com/release-notes/\(caskFile.version)")!
})
.perform()
```

## Self-Updater

As a separate target (for a macOS app), you need to add the following file:

```swift
import Cocoa
import NVAppUpdater

let delegate = SelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    selfUpdaterPath: "~/.config/com.example.my-app/updater"
)

NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
```

You must then make sure that this app is included as a sub-app for the main target. The Self-Updater target needs to be referenced correctly as part of the `selfUpdaterName` parameter of `UpdateCheck`, or the `UpdateCheck` won't be able to launch the updater binary itself.

### Progress window display mode

By default, the self-updater only shows the progress window when the update takes longer than 3 seconds. This avoids showing a window for very fast updates.

If you always want to show the progress window, set `progressWindowDisplayMode` when creating the `SelfUpdater`:

```swift
let delegate = SelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    selfUpdaterPath: "~/.config/com.example.my-app/updater",
    progressWindowDisplayMode: .always
)
```

You can also customize the delay:

```swift
let delegate = SelfUpdater(
    appName: "My App",
    bundleIdentifiers: ["com.example.my-app"],
    selfUpdaterPath: "~/.config/com.example.my-app/updater",
    progressWindowDisplayMode: .whenUpdatingTakesLongerThan(5)
)
```

## Customizing text

The default alert and progress window text can be overridden before you run an update check or launch the self-updater. This is useful if you have an app with localization.

### Checking for updates

Use `UpdateCheck.Translations` for the main app prompts:

```swift
UpdateCheck.Translations.updateAvailableTitle = "A new version of %@ is ready."
UpdateCheck.Translations.updateAvailableSubtitle = "Version %@ can now be installed."
UpdateCheck.Translations.updateAvailableDescription = "Would you like to install this update now?"
UpdateCheck.Translations.buttonInstall = "Upgrade"
UpdateCheck.Translations.buttonOK = "OK"
UpdateCheck.Translations.buttonDismiss = "Not Now"
UpdateCheck.Translations.buttonViewReleaseNotes = "Release Notes"
```

Strings that contain `%@` will substitute the application name or version, depending on the string.

### Updater progress window and errors

Use `SelfUpdater.Translations` for the self-updater progress window and manifest failure text:

```swift
SelfUpdater.Translations.progressWindowTitle = "Updating %@"
SelfUpdater.Translations.progressStepDownloadingUpdate = "Downloading update"
SelfUpdater.Translations.progressStepExtractingUpdate = "Extracting update"
SelfUpdater.Translations.progressStepRestartingApp = "Restarting %@"
SelfUpdater.Translations.downloadProgressWaitingForSize = "Preparing download..."
SelfUpdater.Translations.downloadProgressByteCountFormat = "%@ of %@"
SelfUpdater.Translations.invalidManifestURLDescription = "The update manifest contains an invalid download URL. Please try searching for updates again in %@."
SelfUpdater.Translations.missingManifestDescription = "The manifest file for a potential update was not found. Please try searching for updates again in %@."
SelfUpdater.Translations.checksumValidationFailedDescription = "The downloaded update failed checksum validation. Please try again. If this issue persists, there may be an issue with the server and I do not recommend upgrading."
SelfUpdater.Translations.upgradeFailureTitle = "%@ could not be updated."
SelfUpdater.Translations.buttonOK = "OK"
SelfUpdater.Translations.downloadFailedDescription = "The update could not be downloaded.\n\n%@\n\nPlease check your internet connection and try again."
SelfUpdater.Translations.downloadTimedOutDescription = "The download timed out."
SelfUpdater.Translations.downloadUnexpectedStatusDescription = "The server returned an unexpected response (status %@)."
SelfUpdater.Translations.downloadFileSaveFailedDescription = "The downloaded file could not be saved: %@"
SelfUpdater.Translations.updaterDirectoryMissingDescription = "The updater directory is missing. The automatic updater will quit. Make sure that `%@` is writeable."
SelfUpdater.Translations.extractionFailedDescription = "The downloaded file could not be extracted. The automatic updater will quit. Make sure that `%@` is writeable."
SelfUpdater.Translations.terminationFailedDescription = "%@ could not be quit before installing the update. Please quit the app manually and try again."
```

## Upgrading

See [UPGRADING.md](UPGRADING.md) for the v2 to v3 upgrade guide.
