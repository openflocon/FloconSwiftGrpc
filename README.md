# Flocon gRPC for iOS

Logs the gRPC calls of your app in the Network section of [Flocon](https://github.com/openflocon/Flocon), the desktop debugger for mobile apps. An add-on for [FloconSwift](https://github.com/openflocon/FloconSwift) and [grpc-swift](https://github.com/grpc/grpc-swift) 1.x.

<!-- screenshot: hero -->

Each call shows up with the server and the full method name (`helloworld.Greeter/SayHello`), the request and response messages as JSON, the metadata, the duration, the gRPC status (`OK`, `NOT_FOUND`...) and the error when the call fails.

## Requirements

- iOS 15+ or macOS 12+, Xcode 16+ (Swift 6.0)
- grpc-swift 1.26.0 or a later 1.x version
- FloconSwift 2.0.0 or later (added automatically)
- The [Flocon desktop app](https://github.com/openflocon/Flocon) running on your Mac

## Installation

Add the package with Swift Package Manager (**File > Add Package Dependencies...** in Xcode), then add the `FloconGrpc` library to your app target:

```swift
dependencies: [
    .package(url: "https://github.com/openflocon/FloconSwiftGrpc.git", from: "2.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "FloconGrpc", package: "FloconSwiftGrpc"),
    ]),
]
```

`import FloconGrpc` re-exports `Flocon`: it is enough to start the SDK. For the Info.plist keys, the simulator and the physical device, see the [FloconSwift README](https://github.com/openflocon/FloconSwift#quick-start).

## Usage

Start Flocon with the network plugin, which the calls are logged through (`Flocon.initialize()` installs every plugin):

```swift
startFlocon { flocon in
    flocon.install(.network)
}
```

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

`authority` is shown as the URL of the calls: an interceptor does not know the channel it runs on. The interceptor does nothing before the SDK is started.

Streaming calls are only partly logged: the first request message and the last response message are shown.

More about gRPC in Flocon: [gRPC documentation](https://openflocon.github.io/Flocon/grpc/). Everything else (network, databases, files...): [openflocon.github.io/Flocon](https://openflocon.github.io/Flocon/).

## Sample app

`FloconGrpcDemo` calls the `helloworld` server of grpc-go.

1. Start the test server on `localhost:50051` (needs Go): `./grpc-test-server/start.sh`
2. Open `FloconGrpcDemo/FloconGrpcDemo.xcodeproj` and run it on the iOS Simulator.
3. Tap **Say hello**: the call shows up in Flocon. The second button calls a closed port, to see a failed call.

## Contributing and license

Issues and pull requests are welcome. MIT, see [LICENSE](LICENSE).
