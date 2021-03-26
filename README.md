# CiteprocRsKit

A very WIP set of Swift bindings for
[`citeproc-rs`](https://github.com/zotero/citeproc-rs).

## Prerequisites for building

* Xcode 12 (not tested on lesser Xcodes)
* `rustup` (installed any method, must have nightly toolchain installed. tip: `brew install rustup`)
* `jq` (must be Homebrew or in Xcode's default path somehow, `brew install jq`)

You'll need [Carthage](https://github.com/Carthage/Carthage) v0.37+ (e.g. `brew install
carthage`) to follow the instructions below. Which are probably the easiest
possible way and quite neat indeed. You probably want to .gitignore the
Carthage folder.

## Adding as a dependency to an Xcode project

Add this repo as a Carthage dependency. With a branch name for now as no tags
exist.

```
# Cartfile
git "cormacrelf/CiteprocRsKit" "master"
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

## Pre-built Binaries

None at the moment, but there is no reason the long build phase couldn't be
avoided by producing an `.xcframework` on CI. Then either:

- Adding as a `.binaryTarget()` in a Swift Package Manager (SPM)
`Package.swift` file, using a GitHub releases URL and a checksum
- Publishing it it to a swift package registry of some kind??? No such thing
exists yet.
