// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FloconGrpc",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "FloconGrpc", targets: ["FloconGrpc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/openflocon/FloconSwift.git", from: "0.2.0"),
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
