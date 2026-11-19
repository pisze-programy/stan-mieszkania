import Foundation

public protocol ServerErrorCodeConvertible: Error, Sendable {
  var serverErrorCode: ServerErrorCode { get }
}
