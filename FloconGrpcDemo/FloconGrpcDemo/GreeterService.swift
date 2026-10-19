import FloconGrpc
import GRPC

/// Calls the `helloworld.Greeter` service of the local test server, started by `grpc-test-server/start.sh`.
///
/// The iOS Simulator reaches the Mac at `localhost`. On a device, use the IP address of the Mac.
final class GreeterService: Sendable {
    static let host = "localhost"
    static let port = 50051
    /// Port where nothing listens, to see a failed call in Flocon.
    static let closedPort = 50052

    private let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

    /// Sends `SayHello` and returns the message of the reply.
    func sayHello(name: String, port: Int = GreeterService.port) async throws -> String {
        let channel = try GRPCChannelPool.with(
            target: .host(Self.host, port: port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        ) { $0.connectionBackoff.retries = .upTo(1) }
        defer { channel.close().whenComplete { _ in } }

        let client = Helloworld_GreeterAsyncClient(
            channel: channel,
            defaultCallOptions: CallOptions(timeLimit: .timeout(.seconds(5))),
            interceptors: FloconInterceptors(authority: "\(Self.host):\(port)")
        )
        let reply = try await client.sayHello(.with { $0.name = name })
        return reply.message
    }
}

/// Adds the Flocon interceptor to each method of the generated client.
private struct FloconInterceptors: Helloworld_GreeterClientInterceptorFactoryProtocol {
    let authority: String

    func makeSayHelloInterceptors() -> [ClientInterceptor<Helloworld_HelloRequest, Helloworld_HelloReply>] {
        [FloconGrpcClientInterceptor(authority: authority)]
    }
}
