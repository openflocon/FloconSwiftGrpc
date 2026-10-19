import Foundation
import GRPC
import NIOCore
import NIOHPACK

/// Logs the calls of a gRPC client in the Network section of the Flocon desktop app.
///
/// grpc-swift creates the interceptors of each call from the interceptor factory of the
/// generated client. Return a new interceptor for each method:
///
/// ```swift
/// final class GreeterInterceptors: Helloworld_GreeterClientInterceptorFactoryProtocol {
///     func makeSayHelloInterceptors() -> [ClientInterceptor<Helloworld_HelloRequest, Helloworld_HelloReply>] {
///         [FloconGrpcClientInterceptor(authority: "api.example.com:443")]
///     }
/// }
///
/// let client = Helloworld_GreeterNIOClient(channel: channel, interceptors: GreeterInterceptors())
/// ```
///
/// Each call shows up with the server as URL, the full name of the method
/// (`helloworld.Greeter/SayHello`), the messages as JSON, the metadata, the duration and the
/// gRPC status. For a streaming call, the first request message and the last response
/// message are shown.
///
/// The interceptor does nothing before `Flocon.initialize()`.
public final class FloconGrpcClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
    private let authority: String
    private let logger: FloconGrpcCallLogger
    private let callId = UUID().uuidString

    // grpc-swift calls an interceptor from the event loop of its call only: no lock needed
    private var startTime: Date?
    private var requestHeaders: [String: String] = [:]
    private var isRequestLogged = false
    private var isResponseLogged = false
    private var responseHeaders: [String: String] = [:]
    private var lastResponse: Response?

    /// Creates an interceptor.
    ///
    /// - Parameter authority: Server called by the client, shown as the URL of the calls,
    ///   for example `api.example.com:443`. An interceptor does not know the channel it runs on.
    public convenience init(authority: String) {
        self.init(authority: authority, logger: FloconSDKCallLogger())
    }

    init(authority: String, logger: FloconGrpcCallLogger) {
        self.authority = authority
        self.logger = logger
        super.init()
    }

    // MARK: Request

    override public func send(
        _ part: GRPCClientRequestPart<Request>,
        promise: EventLoopPromise<Void>?,
        context: ClientInterceptorContext<Request, Response>
    ) {
        if logger.isEnabled {
            switch part {
            case .metadata(let headers):
                requestHeaders = FloconGrpcFormatter.headers(headers)
            case .message(let message, _):
                logRequestOnce(message, path: context.path)
            case .end:
                break
            }
        }
        context.send(part, promise: promise)
    }

    private func logRequestOnce(_ message: Request, path: String) {
        guard !isRequestLogged else { return }
        isRequestLogged = true
        let start = Date()
        startTime = start
        logger.logRequest(
            callId: callId,
            url: authority,
            method: path.hasPrefix("/") ? String(path.dropFirst()) : path,
            startTime: start,
            headers: requestHeaders,
            body: FloconGrpcFormatter.json(of: message),
            size: FloconGrpcFormatter.size(of: message)
        )
    }

    // MARK: Response

    override public func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        if logger.isEnabled {
            switch part {
            case .metadata(let headers):
                responseHeaders = FloconGrpcFormatter.headers(headers)
            case .message(let message):
                lastResponse = message
            case .end(let status, let trailers):
                logResponse(status: status, trailers: trailers)
            }
        }
        context.receive(part)
    }

    // a transport error, such as a connection failure, reaches the interceptors here, not in `.end`
    override public func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
        if logger.isEnabled {
            let status = (error as? GRPCStatusTransformable)?.makeGRPCStatus()
                ?? GRPCStatus(code: .unknown, message: String(describing: error), cause: error)
            logResponse(status: status, trailers: [:])
        }
        context.errorCaught(error)
    }

    private func logResponse(status: GRPCStatus, trailers: HPACKHeaders) {
        // interceptors run before the transport: the request is logged even when the connection fails
        guard let startTime, !isResponseLogged else { return }
        isResponseLogged = true

        var headers = responseHeaders
        headers.merge(FloconGrpcFormatter.headers(trailers)) { _, trailer in trailer }
        let error = status.cause.map { cause in status.message.map { "\($0): \(cause)" } ?? String(describing: cause) }

        logger.logResponse(
            callId: callId,
            durationMs: Date().timeIntervalSince(startTime) * 1000,
            grpcStatus: FloconGrpcFormatter.name(of: status.code),
            body: lastResponse.flatMap(FloconGrpcFormatter.json(of:)) ?? (status.isOk ? nil : status.message),
            headers: headers,
            size: lastResponse.flatMap(FloconGrpcFormatter.size(of:)),
            error: error
        )
    }
}
