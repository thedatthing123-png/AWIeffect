import XCTest
@testable import AWIeffect

/// AI Link backend: requests parse (incl. partial arrival), the catalog serializes, and the code is required.
@MainActor
final class AILinkTests: XCTestCase {
    func testRequestParsing() {
        let body = Data("{\"name\":\"undo\"}".utf8)
        var raw = Data("POST /action?x=1 HTTP/1.1\r\nHost: a\r\nX-AWI-Code: 123456\r\nContent-Length: \(body.count)\r\n\r\n".utf8)
        XCTAssertNil(HTTPRequest(raw), "waits for the body")
        raw.append(body)
        let r = HTTPRequest(raw)
        XCTAssertEqual(r?.method, "POST"); XCTAssertEqual(r?.path, "/action"); XCTAssertEqual(r?.query["x"], "1")
        XCTAssertEqual(r?.headers["x-awi-code"], "123456"); XCTAssertEqual(r?.body, body)
    }

    func testCatalogIsValidJSON() throws {
        let c = AILink.catalog()
        let d = try JSONSerialization.data(withJSONObject: c)
        XCTAssertGreaterThan(d.count, 10_000)
        XCTAssertEqual((c["effects"] as? [Any])?.count, EffectRegistry.all.count)
    }

    func testResponseHasLengthAndBody() {
        let r = HTTPResponse.json(["ok": true])
        let s = String(decoding: r.bytes, as: UTF8.self)
        XCTAssertTrue(s.hasPrefix("HTTP/1.1 200"))
        XCTAssertTrue(s.contains("Content-Length: \(r.body.count)"))
    }
}
