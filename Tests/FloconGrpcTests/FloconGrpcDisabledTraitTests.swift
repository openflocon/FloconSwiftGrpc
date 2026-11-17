#if !FloconEnabled
import GRPC
import NIOPosix
import Testing
import FloconGrpc

/// Greets everyone.
final class GreeterProvider: Helloworld_GreeterAsyncProvider {
    func sayHello(request: Helloworld_HelloRequest, context: GRPCAsyncServerCallContext) async throws -> Helloworld_HelloReply {
        .with { $0.message = "Hello \(request.name)" }
    }
}

struct ForwardingInterceptors: Helloworld_GreeterClientInterceptorFactoryProtocol {
    func makeSayHelloInterceptors() -> [ClientInterceptor<Helloworld_HelloRequest, Helloworld_HelloReply>] {
        [FloconGrpcClientInterceptor(authority: "127.0.0.1")]
    }
}

@Suite struct FloconGrpcDisabledTraitTests {
    @Test func leavesTheSDKOut() {
        #expect(!Flocon.isEnabled)
    }

    @Test func forwardsTheCalls() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try await Server.insecure(group: group)
            .withServiceProviders([GreeterProvider()])
            .bind(host: "127.0.0.1", port: 0)
            .get()
        let channel = try GRPCChannelPool.with(
            target: .host("127.0.0.1", port: server.channel.localAddress?.port ?? 0),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        let client = Helloworld_GreeterAsyncClient(channel: channel, interceptors: ForwardingInterceptors())

        let reply = try await client.sayHello(.with { $0.name = "Ada" })

        #expect(reply.message == "Hello Ada")
        try await channel.close().get()
        try await server.close().get()
        try await group.shutdownGracefully()
    }
}
#endif
