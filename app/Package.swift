// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LibraryApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LibraryApp", targets: ["LibraryApp"])
    ],
    targets: [
        .executableTarget(
            name: "LibraryApp",
            path: "LibraryApp"
        ),
        .testTarget(
            name: "LibraryAppTests",
            dependencies: ["LibraryApp"],
            path: "LibraryAppTests"
        )
    ]
)
