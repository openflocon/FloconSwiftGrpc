import Foundation
import GRPC
import NIOCore
import NIOPosix
import Testing
@testable import FloconGrpc

// MARK: - Test doubles

/// Records what an interceptor logs, instead of sending it to the desktop app.
final class RecordingCallLogger: FloconGrpcCallLogger, @unchecked Sendable {
    struct Request { let callId, url, method: String; let headers: [String: String]; let body: String?; let size: Int64? }
    struct Response { let callId, grpcStatus: String; let body: String?; let size: Int64?; let error: String? }

    private let lock = NSLock()
    private var _requests: [Request] = []
    private var _responses: [Response] = []
    let isEnabled: Bool

    init(isEnabled: Bool = true) { self.isEnabled = isEnabled }

    var requests: [Request] { lock.withLock { _requests } }
    var responses: [Response] { lock.withLock { _responses } }

    func logRequest(callId: String, url: String, method: String, startTime: Date, headers: [String: String], body: String?, size: Int64?) {
        lock.withLock { _requests.append(.init(callId: callId, url: url, method: method, headers: headers, body: body, size: size)) }
    }

    func logResponse(callId: String, durationMs: Double, grpcStatus: String, body: String?, headers: [String: String], size: Int64?, error: String?) {
        lock.withLock { _responses.append(.init(callId: callId, grpcStatus: grpcStatus, body: body, size: size, error: error)) }
    }
}

/// Greets everyone, except "missing", who is not found.
final class GreeterProvider: Helloworld_GreeterAsyncProvider {
    func sayHello(request: Helloworld_HelloRequest, context: GRPCAsyncServerCallContext) async throws -> Helloworld_HelloReply {
        if request.name == "missing" {
            throw GRPCStatus(code: .notFound, message: "no user named missing")
        }
        return .with { $0.message = "Hello \(request.name)" }
    }
}

struct GreeterInterceptors: Helloworld_GreeterClientInterceptorFactoryProtocol {
    let logger: FloconGrpcCallLogger
    let authority: String

    func makeSayHelloInterceptors() -> [ClientInterceptor<Helloworld_HelloRequest, Helloworld_HelloReply>] {
        [FloconGrpcClientInterceptor(authority: authority, logger: logger)]
    }
}

// MARK: - Tests

@Suite(.serialized) struct FloconGrpcClientInterceptorTests {
    private func withGreeter(
        serverRunning: Bool = true,
        logger: RecordingCallLogger,
        _ body: (Helloworld_GreeterAsyncClient) async throws -> Void
    ) async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        var port = 1 // nothing listens there
        var server: Server?
        if serverRunning {
            server = try await Server.insecure(group: group)
                .withServiceProviders([GreeterProvider()])
                .bind(host: "127.0.0.1", port: 0)
                .get()
            port = server?.channel.localAddress?.port ?? 0
        }
        let channel = try GRPCChannelPool.with(
            target: .host("127.0.0.1", port: port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        ) { $0.connectionBackoff.retries = .none }
        let client = Helloworld_GreeterAsyncClient(
            channel: channel,
            interceptors: GreeterInterceptors(logger: logger, authority: "127.0.0.1:\(port)")
        )

        try await body(client)

        try await channel.close().get()
        try await server?.close().get()
        try await group.shutdownGracefully()
    }

    @Test func logsASuccessfulCall() async throws {
        let logger = RecordingCallLogger()
        try await withGreeter(logger: logger) { client in
            let reply = try await client.sayHello(.with { $0.name = "Florent" })
            #expect(reply.message == "Hello Florent")
        }

        let request = try #require(logger.requests.first)
        #expect(logger.requests.count == 1)
        #expect(request.method == "helloworld.Greeter/SayHello")
        #expect(request.url.hasPrefix("127.0.0.1:"))
        #expect(request.body == #"{"name":"Florent"}"#)
        #expect(request.size == 9)

        let response = try #require(logger.responses.first)
        #expect(response.callId == request.callId)
        #expect(response.grpcStatus == "OK")
        #expect(response.body == #"{"message":"Hello Florent"}"#)
        #expect(response.error == nil)
    }

    @Test func logsAnErrorStatusOfTheServer() async throws {
        let logger = RecordingCallLogger()
        try await withGreeter(logger: logger) { client in
            await #expect(throws: GRPCStatus.self) {
                try await client.sayHello(.with { $0.name = "missing" })
            }
        }

        let response = try #require(logger.responses.first)
        #expect(response.grpcStatus == "NOT_FOUND")
        #expect(response.body == "no user named missing")
    }

    @Test func logsAConnectionFailure() async throws {
        let logger = RecordingCallLogger()
        try await withGreeter(serverRunning: false, logger: logger) { client in
            await #expect(throws: (any Error).self) {
                try await client.sayHello(.with { $0.name = "Florent" }, callOptions: CallOptions(timeLimit: .timeout(.seconds(2))))
            }
        }

        #expect(logger.requests.count == 1)
        let response = try #require(logger.responses.first)
        #expect(response.grpcStatus == "UNAVAILABLE" || response.grpcStatus == "DEADLINE_EXCEEDED")
    }

    @Test func doesNothingWhenFloconIsNotStarted() async throws {
        let logger = RecordingCallLogger(isEnabled: false)
        try await withGreeter(logger: logger) { client in
            _ = try await client.sayHello(.with { $0.name = "Florent" })
        }
        #expect(logger.requests.isEmpty && logger.responses.isEmpty)
    }

    @Test func namesTheStatusCodesLikeTheOtherImplementations() {
        #expect(FloconGrpcFormatter.name(of: .ok) == "OK")
        #expect(FloconGrpcFormatter.name(of: .notFound) == "NOT_FOUND")
        #expect(FloconGrpcFormatter.name(of: .unavailable) == "UNAVAILABLE")
        #expect(FloconGrpcFormatter.name(of: .internalError) == "INTERNAL")
    }
}
