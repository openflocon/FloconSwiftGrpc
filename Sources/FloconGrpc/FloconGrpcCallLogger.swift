import Foundation
@_spi(FloconExtension) import Flocon

/// Where an interceptor logs its calls: the Flocon SDK, or a recorder in the tests.
protocol FloconGrpcCallLogger: Sendable {
    var isEnabled: Bool { get }

    func logRequest(callId: String, url: String, method: String, startTime: Date, headers: [String: String], body: String?, size: Int64?)

    func logResponse(
        callId: String,
        durationMs: Double,
        grpcStatus: String,
        body: String?,
        headers: [String: String],
        size: Int64?,
        error: String?
    )
}

/// Logs the calls in the Network section of the Flocon desktop app.
struct FloconSDKCallLogger: FloconGrpcCallLogger {
    private static let networkType = "grpc"

    var isEnabled: Bool { Flocon.isNetworkLoggingEnabled }

    func logRequest(callId: String, url: String, method: String, startTime: Date, headers: [String: String], body: String?, size: Int64?) {
        Flocon.logNetworkRequest(
            callId: callId,
            networkType: Self.networkType,
            url: url,
            method: method,
            startTime: startTime,
            headers: headers,
            body: body,
            size: size
        )
    }

    func logResponse(
        callId: String,
        durationMs: Double,
        grpcStatus: String,
        body: String?,
        headers: [String: String],
        size: Int64?,
        error: String?
    ) {
        Flocon.logNetworkResponse(
            callId: callId,
            networkType: Self.networkType,
            durationMs: durationMs,
            httpCode: nil,
            grpcStatus: grpcStatus,
            contentType: "grpc",
            body: body,
            headers: headers,
            size: size,
            error: error
        )
    }
}
