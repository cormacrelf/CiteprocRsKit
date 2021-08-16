# CiteprocRsKit

A set of Swift bindings for
[`citeproc-rs`](https://github.com/zotero/citeproc-rs).

## Pre-built Binaries

Add the repo [`https://github.com/cormacrelf/CiteprocRsKit-Binary`][bin] as a
dependency in a Package.swift file, or in Xcode's Swift packages list. Versions
in that repo align with tagged releases in this repo. It is a cross-platform
xcframework built for macOS, iOS and the iOS Simulator.

For Package.swift, follow the docs [here][v1] and [here][v2] for version requirements.

[bin]: https://github.com/cormacrelf/CiteprocRsKit-Binary
[v1]: https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#package-dependency
[v2]: https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#package-dependency-requirement

```swift
// Package.swift
// ...
dependencies: [
    // exact version best for sub-1.0.0 releases as SwiftPM doesn't consider an
    // 0.x to 0.x+1 change a "major version" despite Semver
    .package(name: "CiteprocRsKit", url: "https://github.com/cormacrelf/CiteprocRsKit-Binary", .exact("0.2.1")),
],
targets: [
    // and add it as a dependency to a target in your own project
    .target(name: "MyApp", dependencies: ["CiteprocRsKit"])
]
```

## Using Carthage

### Prerequisites for building

* Xcode 12 (not tested on lesser Xcodes)
* `rustup` (installed any method, must have nightly toolchain installed. tip: `brew install rustup`)
* `jq` (must be Homebrew or in Xcode's default path somehow, `brew install jq`)

You'll need [Carthage](https://github.com/Carthage/Carthage) v0.37+ (e.g. `brew install
carthage`) to follow the instructions below. Which are probably the easiest
possible way and quite neat indeed. You probably want to .gitignore the
Carthage folder.

### Adding as a dependency to an Xcode project

Add this repo as a Carthage dependency.

```
# Cartfile
git "cormacrelf/CiteprocRsKit" "master" # or a tag
```

Then use Carthage in XCFramework mode. The legacy mode does not work because
CiteprocRsKit is a multi-arch target and it will fail to `lipo` all the archs
together because there are archs in common between
macos,iphonesimulator,iphoneos platforms these days.

```sh
carthage update --use-xcframeworks
# add `--platform ios` if you don't need the macos build as well

# if you have CiteprocRsKit in your lockfile already and don't want to update, run
carthage build --use-xcframeworks

# basically just read the carthage docs
```

Drag the Carthage/Build/CiteprocRsKit.xcframework into your target's Frameworks
and Libraries list in the configuration editor.

This is a static library, so you need to select `Do Not Embed` when you drag it
in. Embedding is for dylib frameworks who need to be copied to the output (e.g.
inside a .app/ipa) and signed, but this one is statically linked to your Swift
code.

Then in a swift file:

```swift
import CiteprocRsKit
// follow the test suite in CiteprocRsKitTests for usage so far
```

