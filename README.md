# Flocon gRPC for iOS

Logs the gRPC calls of your app in the Network section of [Flocon](https://github.com/openflocon/Flocon), the desktop debugging tool for mobile apps.

It extends [FloconSwift](https://github.com/openflocon/FloconSwift) for apps using [grpc-swift](https://github.com/grpc/grpc-swift) 1.x. It is a separate package so that apps without gRPC only depend on FloconSwift, without grpc-swift and SwiftNIO.

Each call shows up with:
- the server as URL, and the full name of the method (`helloworld.Greeter/SayHello`);
- the request and response messages as JSON;
- the metadata, the duration and the gRPC status (`OK`, `NOT_FOUND`…);
- the error, such as a refused connection, when the call fails.

## Requirements

- iOS 15+ or macOS 12+
- grpc-swift 1.26.0 or a later 1.x version
- FloconSwift 2.0.0 or later (added automatically)
- The [Flocon desktop app](https://github.com/openflocon/Flocon) running on your Mac

## Installation

Add the package with Swift Package Manager, then add the `FloconGrpc` library to your app target:

```swift
dependencies: [
    .package(url: "https://github.com/openflocon/FloconSwiftGrpc.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "FloconGrpc", package: "FloconSwiftGrpc"),
    ]),
]
```

`FloconGrpc` includes FloconSwift: `import FloconGrpc` is enough to start the SDK, with `Flocon.initialize()` or `startFlocon { ... }`.

## Usage

grpc-swift creates the interceptors of each call from the interceptor factory of the generated client. Return a `FloconGrpcClientInterceptor` for each method:

```swift
import FloconGrpc
import GRPC

struct GreeterInterceptors: Helloworld_GreeterClientInterceptorFactoryProtocol {
    func makeSayHelloInterceptors() -> [ClientInterceptor<Helloworld_HelloRequest, Helloworld_HelloReply>] {
        [FloconGrpcClientInterceptor(authority: "api.example.com:443")]
    }
}

let client = Helloworld_GreeterAsyncClient(channel: channel, interceptors: GreeterInterceptors())
```

`authority` is shown as the URL of the calls: an interceptor does not know the channel it runs on.

The interceptor does nothing before the SDK is started. If you start it with `startFlocon`, install the network plugin, which the calls are logged through, with a FloconSwift version that has `startFlocon`:

```swift
startFlocon { flocon in
    flocon.install(.network)
}
```

`Flocon.initialize()` installs every plugin, so it needs nothing more. For a streaming call, the first request message and the last response message are shown.

## Sample app

`FloconGrpcDemo` calls the `helloworld` server of grpc-go, like the Android sample of Flocon.

1. Start the test server on `localhost:50051` (needs Go: `brew install go`):
   ```bash
   ./grpc-test-server/start.sh
   ```
2. Open `FloconGrpcDemo/FloconGrpcDemo.xcodeproj` and run the `FloconGrpcDemo` scheme on the iOS Simulator.
3. Tap **Say hello**: the call shows up in the Network section of Flocon. The second button calls a closed port, to see a failed call.

The Swift code of `protos/helloworld.proto` is generated with `protoc`, `protoc-gen-swift` and `protoc-gen-grpc-swift`, and committed: building the sample needs no code generation.
