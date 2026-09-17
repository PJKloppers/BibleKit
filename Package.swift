// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BibleKit",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "BibleKit", targets: ["BibleKit"])
    ],
    targets: [
        .target(
            name: "BibleKit",
            resources: [.copy("Resources/Holy-Bible-XML-Format/Afrikaans2020Bible.xml")]
        )
    ]
)
