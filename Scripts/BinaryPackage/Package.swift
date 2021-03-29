// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "CiteprocRsKit",
    products: [
        .library(
            name: "CiteprocRsKit",
            targets: ["CiteprocRsKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "CiteprocRsKit",
            url: "XCFRAMEWORK_ZIP_URL",
            checksum: "XCFRAMEWORK_ZIP_CHECKSUM"
        ),
    ]
)
