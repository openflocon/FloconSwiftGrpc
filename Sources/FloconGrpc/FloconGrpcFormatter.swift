import Foundation
import GRPC
import NIOHPACK
import SwiftProtobuf

/// Turns gRPC messages, statuses and metadata into the text shown by the Flocon desktop app.
enum FloconGrpcFormatter {
    /// The message as JSON, or `nil` if it is not a protobuf message.
    ///
    /// As in proto3 JSON, the fields left to their default value are omitted.
    static func json(of message: Any) -> String? {
        guard let message = message as? SwiftProtobuf.Message else { return nil }
        return try? message.jsonString()
    }

    /// Size of the message once serialized, in bytes, or `nil` if it is not a protobuf message.
    static func size(of message: Any) -> Int64? {
        guard let message = message as? SwiftProtobuf.Message,
              let data: Data = try? message.serializedBytes() else { return nil }
        return Int64(data.count)
    }

    /// Name of a status code, as in the other gRPC implementations: `OK`, `NOT_FOUND`, `UNAVAILABLE`…
    static func name(of code: GRPCStatus.Code) -> String {
        switch code {
        case .ok: "OK"
        case .cancelled: "CANCELLED"
        case .unknown: "UNKNOWN"
        case .invalidArgument: "INVALID_ARGUMENT"
        case .deadlineExceeded: "DEADLINE_EXCEEDED"
        case .notFound: "NOT_FOUND"
        case .alreadyExists: "ALREADY_EXISTS"
        case .permissionDenied: "PERMISSION_DENIED"
        case .resourceExhausted: "RESOURCE_EXHAUSTED"
        case .failedPrecondition: "FAILED_PRECONDITION"
        case .aborted: "ABORTED"
        case .outOfRange: "OUT_OF_RANGE"
        case .unimplemented: "UNIMPLEMENTED"
        case .internalError: "INTERNAL"
        case .unavailable: "UNAVAILABLE"
        case .dataLoss: "DATA_LOSS"
        case .unauthenticated: "UNAUTHENTICATED"
        default: "CODE_\(code.rawValue)"
        }
    }

    /// The metadata as a dictionary. Values of a repeated name are joined with `, `.
    static func headers(_ metadata: HPACKHeaders) -> [String: String] {
        var headers: [String: String] = [:]
        for (name, value, _) in metadata {
            headers[name] = headers[name].map { "\($0), \(value)" } ?? value
        }
        return headers
    }
}
