// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BibleKit",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "BibleKit", targets: ["BibleKit"])
    ],
    dependencies: {
        var dependencies: [Package.Dependency] = []
        #if !os(iOS)
        dependencies.append(
            .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
        )
        #endif
        return dependencies
    }(),
    targets: [
        .target(
            name: "BibleKit",
            resources: [.copy("Resources/Holy-Bible-XML-Format/Afrikaans2020Bible.xml")]
        )
    ]
)
