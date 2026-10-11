import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Answers every request from a test-supplied handler instead of the network.
/// The handler returns a status code and body, or throws a URLError to simulate
/// a transport failure. Every request seen is recorded so tests can count retries.
final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (Int, Data)
    /// Same as `Handler` but also returns response headers (e.g. Retry-After).
    typealias HeaderHandler = (URLRequest) throws -> (Int, [String: String], Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: HeaderHandler?
    nonisolated(unsafe) private static var _requests: [URLRequest] = []

    static func reset(handler: @escaping Handler) {
        resetWithHeaders(handler: { request in
            let (status, data) = try handler(request)
            return (status, [:], data)
        })
    }

    static func resetWithHeaders(handler: @escaping HeaderHandler) {
        lock.lock(); defer { lock.unlock() }
        _handler = handler
        _requests = []
    }

    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    /// A session whose only transport is this protocol.
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requests.append(request)
        let handler = Self._handler
        Self.lock.unlock()

        do {
            guard let handler else { throw URLError(.unknown) }
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
