// swift-tools-version: 6.0
//
//  Test-only package for the Kumyk keyboard's product layer.
//
//  The keyboard engine lives in the General Keyboard package
//  (../GeneralKeyboard-iOS) and is tested there. This package tests what
//  Kumyk adds on top: `KumykCore` compiles the very same product files
//  that ship inside the KumykKeyboardExtension target (the definition,
//  layout, strings and identity), via an explicit `sources:` list, and the
//  tests run them through the real engine: the definition, the layout
//  against the pinned Russian baseline and Kumyk long-press mapping, the
//  shipped dictionary artifacts,
//  learning and the typing path.
//
//  Run from the repo root (General Keyboard checked out next to this repo):
//    xcodebuild test -scheme KumykCoreTests-Package \
//      -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
//
//  iOS-only by design: the layout and the engine use UIKit types.
//
import PackageDescription

let package = Package(
    name: "KumykCoreTests",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(path: "../GeneralKeyboard-iOS"),
    ],
    targets: [
        .target(
            name: "KumykCore",
            dependencies: [.product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "KumykKeyboard/KumykKeyboardExtension",
            sources: [
                "KumykDefinition.swift",
                "KumykLayout.swift",
                "KumykStrings.swift",
                "KumykIdentity.swift",
            ]
        ),
        .testTarget(
            name: "KumykCoreTests",
            dependencies: ["KumykCore", .product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "Tests/KumykCoreTests",
            // Read through #filePath (like the shipped artifacts), not bundled.
            exclude: ["Fixtures"]
        ),
    ]
)
