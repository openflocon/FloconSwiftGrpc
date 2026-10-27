import Foundation
import Flocon

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

/// Logs the calls in the Network section of the Flocon desktop app, through its network plugin.
///
/// `Flocon.networkPlugin` does nothing when the SDK is not started, so `isEnabled` only avoids
/// building the logs for nothing.
struct FloconSDKCallLogger: FloconGrpcCallLogger {
    private static let networkType = "grpc"

    var isEnabled: Bool { Flocon.shared.networkPlugin != nil }

    func logRequest(callId: String, url: String, method: String, startTime: Date, headers: [String: String], body: String?, size: Int64?) {
        Flocon.networkPlugin.logRequest(
            FloconNetworkCallRequest(
                callId: callId,
                networkType: Self.networkType,
                request: FloconNetworkRequest(url: url, method: method, startTime: startTime, headers: headers, body: body, size: size)
            )
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
        Flocon.networkPlugin.logResponse(
            FloconNetworkCallResponse(
                callId: callId,
                networkType: Self.networkType,
                durationMs: durationMs,
                response: FloconNetworkResponse(
                    grpcStatus: grpcStatus,
                    contentType: "grpc",
                    body: body,
                    size: size,
                    headers: headers,
                    error: error
                )
            )
        )
    }
}
