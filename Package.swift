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
    targets: [
        .executableTarget(
            name: "MatrixApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
