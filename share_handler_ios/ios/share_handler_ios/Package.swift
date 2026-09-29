// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "share_handler_ios",
    platforms: [.iOS("16.0")],
    products: [
        .library(name: "share-handler-ios", targets: ["share_handler_ios"]),
        .library(name: "share-handler-ios-models", targets: ["share_handler_ios_models"]),
    ],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(name: "share_handler_ios_models"),
        .target(
            name: "share_handler_ios",
            dependencies: [
                "share_handler_ios_models",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ]
        ),
    ]
)
