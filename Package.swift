// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// To use the debug copy built by Scripts/xcframework
//
//     export CITEPROC_RS_BINARY=local
//     swift test
//
// To test with a draft binary release:
//
//     Scripts/release --release --draft --push-binary-repo
//     export CITEPROC_RS_BINARY=draft
//     # (swift test will fail because the _test_* symbols are not available on release builds)
//     swift build

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


// https://gist.github.com/Sorix/21e61347f478ae2e83ef4d8a92d933af
enum Environment {
    static let `default`: Environment = .preBuiltRelease

    case preBuiltRelease
    case preBuiltDraft
    case localBinary

    struct EnvError: Error {
        let msg: String
        init(env: String) {
            msg = "unrecognised env variable setting CITEPROC_RS_BINARY=\(env)"
        }
    }

    static func get() throws -> Environment {
        if let envPointer = getenv("CITEPROC_RS_BINARY") {
            let env = String(cString: envPointer)
            switch env {
                case "draft": return .preBuiltDraft
                case "local": return .localBinary
                case "": return .default
                default: throw EnvError(env: env)
            }
        } else {
            return .default
        }
    }
}

func releasedPackage(from version: Version) -> Package.Dependency {
    .package(
        name: "CiteprocRs",
        url: "https://github.com/citeproc-rs/ffi-xcframework",
        from: version
    )
}

let draftBranchPackage: Package.Dependency = .package(
    name: "CiteprocRs",
    url: "https://github.com/citeproc-rs/ffi-xcframework",
    .branch("draft")
)


let localTarget: Target = .binaryTarget(
    name: "CiteprocRs",
    path: "citeproc-rs/target/xcframework/debug/CiteprocRs.xcframework"
)

var dependencies: [Package.Dependency] = [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
]
var targets: [Target] = [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
        name: "CiteprocRsKit",
        dependencies: ["CiteprocRs"],
        exclude: ["Info.plist", "Documentation.docc"]
    ),
    .testTarget(
        name: "CiteprocRsKitTests",
        dependencies: ["CiteprocRsKit"],
        exclude: ["Info.plist"]
    ),
]

switch try Environment.get() {
    case .preBuiltRelease: dependencies.append(releasedPackage(from: "1.0.0")); break;
    case .preBuiltDraft: dependencies.append(draftBranchPackage); break;
    case .localBinary: targets.append(localTarget); break
}

let package = Package(
    name: "CiteprocRsKit",
    platforms: [
        .macOS("10.10"),
        .iOS("13.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "CiteprocRsKit", targets: ["CiteprocRsKit"]),
    ],
    dependencies: dependencies,
    targets: targets
)
