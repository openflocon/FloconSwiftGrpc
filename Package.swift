// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "FloconGrpc",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "FloconGrpc", targets: ["FloconGrpc"]),
    ],
    traits: [
        .trait(
            name: "FloconEnabled",
            description: "Logs the gRPC calls, and turns on the FloconEnabled trait of FloconSwift. "
                + "Without it, the interceptor only forwards the calls, for builds that must not contain the SDK."
        ),
        .default(enabledTraits: ["FloconEnabled"]),
    ],
    dependencies: [
        // on one line: the Release workflow bumps the version with sed
        .package(url: "https://github.com/openflocon/FloconSwift.git", from: "2.1.1", traits: [.trait(name: "FloconEnabled", condition: .when(traits: ["FloconEnabled"]))]),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.26.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.1"),
    ],
    targets: [
        .target(
            name: "FloconGrpc",
            dependencies: [
                .product(name: "Flocon", package: "FloconSwift"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        .testTarget(
            name: "FloconGrpcTests",
            dependencies: [
                "FloconGrpc",
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
    ]
)
