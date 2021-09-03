// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "CiteprocRs",
    products: [
        .library(
            name: "CiteprocRs",
            targets: ["CiteprocRs"]),
    ],
    targets: [
        .binaryTarget(
            name: "CiteprocRs",
            url: "XCFRAMEWORK_ZIP_URL",
            checksum: "XCFRAMEWORK_ZIP_CHECKSUM"
        ),
    ]
)
