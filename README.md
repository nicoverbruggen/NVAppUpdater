# NVAppUpdater Package

**Important**: 👷‍♂️ This package is currently **under construction**, and may change at any time.

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
    promptOnFailure: true
).perform()
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

You must then make sure that this app is included as a sub-app for the main target. It needs to be referenced correctly as part of the `selfUpdaterName` parameter of `UpdateCheck` (see the previous section).
