// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MatrixApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MatrixApp", targets: ["MatrixApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MatrixApp",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ],
            resources: [
                .process("Resources"),
                .process("Shaders.metal")
            ]
        )
    ]
)
