import XCTest
@testable import AWIeffect

/// Fake transcriber: returns canned words (Speech can't run in CI).
private struct FakeTranscriber: CaptionTranscribing {
    let words: [CaptionWord]
    func transcribe(url: URL, range: ClosedRange<Double>?, localeID: String,
                    progress: @escaping (Double) -> Void) async throws -> [CaptionWord] {
        progress(1)
        return words
    }
}

final class CaptionsTests: XCTestCase {
    private func w(_ t: String, _ s: Double, _ e: Double) -> CaptionWord { CaptionWord(text: t, start: s, end: e) }

    private var sample: [CaptionWord] {
        [w("hello", 0.0, 0.4), w("there", 0.5, 0.9), w("my", 1.0, 1.2), w("friend", 1.3, 1.8),
         // 1.2 s pause → new line
         w("again", 3.0, 3.5), w("now", 3.6, 4.0)]
    }

    private func project() -> Project { Project.new(name: "c", width: 1080, height: 1920, fps: 30, duration: 10, background: .black) }

    func testGroupingSplitsOnPause() {
        let lines = CaptionTrack.group(sample, rules: CaptionGrouping())
        XCTAssertEqual(lines.map(\.text), ["hello there my friend", "again now"])
    }

    func testGroupingSplitsOnMaxCharacters() {
        var r = CaptionGrouping(); r.maxCharacters = 11
        let lines = CaptionTrack.group(sample, rules: r)
        XCTAssertEqual(lines.map(\.text), ["hello there", "my friend", "again now"])
        XCTAssertTrue(lines.allSatisfy { $0.text.count <= 11 })
    }

    func testGroupingSplitsOnMaxDuration() {
        var r = CaptionGrouping(); r.maxDuration = 1.0; r.pauseGap = 10
        let lines = CaptionTrack.group(sample, rules: r)
        XCTAssertEqual(lines.first?.text, "hello there")
        XCTAssertTrue(lines.allSatisfy { $0.end - $0.start <= 1.0 + 1e-9 })
    }

    func testSplitAndMerge() {
        var t = CaptionTrack(); t.setWords(sample)
        let first = t.lines[0].id
        t.split(lineID: first, at: 2)
        XCTAssertEqual(t.lines.map(\.text), ["hello there", "my friend", "again now"])
        t.mergeWithNext(lineID: t.lines[0].id)
        XCTAssertEqual(t.lines.map(\.text), ["hello there my friend", "again now"])
    }

    func testLayersHaveLineTimes() {
        var t = CaptionTrack(); t.setWords(sample); t.highlight = .fill
        let layers = t.makeLayers(in: project())
        XCTAssertEqual(layers.count, 2)
        XCTAssertEqual(layers[0].text?.string, "hello there my friend")
        XCTAssertEqual(layers[0].inPoint, 0, accuracy: 1e-9)
        XCTAssertEqual(layers[0].outPoint, 1.8 + t.grouping.linger, accuracy: 1e-9)
        XCTAssertEqual(layers[1].inPoint, 3.0, accuracy: 1e-9)
        XCTAssertEqual(layers[1].outPoint, 4.0 + t.grouping.linger, accuracy: 1e-9)
        XCTAssertEqual(layers[0].content, .text)
    }

    func testLineOutStopsAtNextLine() {
        var t = CaptionTrack()
        t.lines = [CaptionLine(words: [w("a", 0, 1)]), CaptionLine(words: [w("b", 1.1, 2)])]
        let times = t.lineTimes()
        XCTAssertEqual(times[0].outPoint, 1.1, accuracy: 1e-9)
    }

    func testWordHighlightActiveOnlyDuringItsWord() {
        var t = CaptionTrack(); t.setWords(sample); t.highlight = .fill
        let line = t.lines[0]
        let anims = t.highlightAnimators(for: line, fontSize: 100)
        XCTAssertEqual(anims.count, 4)
        let count = 4
        for (i, a) in anims.enumerated() {
            let word = line.words[i]
            let mid = (word.start + word.end) / 2
            XCTAssertEqual(SelectorMath.amount(a.selector, index: i, count: count, time: mid), 1, accuracy: 1e-6, "word \(i) at its time")
            XCTAssertEqual(SelectorMath.amount(a.selector, index: i, count: count, time: word.start - 0.2), 0, accuracy: 1e-6)
            XCTAssertEqual(SelectorMath.amount(a.selector, index: i, count: count, time: word.end + 0.2), 0, accuracy: 1e-6)
            for j in 0..<count where j != i {
                XCTAssertEqual(SelectorMath.amount(a.selector, index: j, count: count, time: mid), 0, accuracy: 1e-6, "other word \(j)")
            }
        }
    }

    func testKaraokeWipeProgresses() {
        var t = CaptionTrack(); t.setWords(sample); t.highlight = .karaokeWipe
        let line = t.lines[0]
        let a = t.highlightAnimators(for: line, fontSize: 100)[0]
        let n = Array(line.text).count
        XCTAssertEqual(a.selector.basedOn, .characters)
        XCTAssertEqual(SelectorMath.amount(a.selector, index: 0, count: n, time: -0.5), 0, accuracy: 1e-6)
        XCTAssertEqual(SelectorMath.amount(a.selector, index: 0, count: n, time: 0.45), 1, accuracy: 1e-6)
        XCTAssertEqual(SelectorMath.amount(a.selector, index: n - 1, count: n, time: 0.45), 0, accuracy: 1e-6)
        XCTAssertEqual(SelectorMath.amount(a.selector, index: n - 1, count: n, time: 1.9), 1, accuracy: 1e-6)
    }

    func testGlowAddsUnderlayLayers() {
        var t = CaptionTrack(); t.setWords(sample); t.highlight = .glow
        let layers = t.makeLayers(in: project())
        XCTAssertEqual(layers.count, 4)
        XCTAssertTrue(layers[1].name.hasSuffix("Underlay"))
        XCTAssertEqual(layers[1].inPoint, layers[0].inPoint)
        XCTAssertEqual(layers[1].text?.fill.value(at: 0).a ?? 1, 0, accuracy: 1e-9)
    }

    func testApplyReplacesLayersInOneStepAndKeepsStyle() {
        var p = project()
        var t = CaptionTrack(); t.setWords(sample)
        p.applyCaptions(t)
        XCTAssertEqual(p.layers.count, 2)
        let tr = p.captionTracks!.first!
        XCTAssertEqual(tr.layerIDs.count, 2)
        // Restyle the first line in Text Studio, then re-apply: style kept, old layers replaced.
        let i = p.layers.firstIndex { $0.id == tr.layerIDs[0] }!
        p.layers[i].text?.fontName = "Menlo-Bold"
        var t2 = tr; t2.highlight = .scale
        p.applyCaptions(t2)
        XCTAssertEqual(p.layers.count, 2)
        XCTAssertEqual(p.captionTracks?.count, 1)
        XCTAssertTrue(p.layers.allSatisfy { $0.text?.fontName == "Menlo-Bold" })
        XCTAssertFalse(p.layers.contains { tr.layerIDs.contains($0.id) })
    }

    func testCodableRoundTrip() throws {
        var t = CaptionTrack(); t.setWords(sample); t.highlight = .karaokeWipe; t.highlightColor = RGBA(1, 0, 0.5)
        var p = project(); p.applyCaptions(t)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(back.captionTracks, p.captionTracks)
        XCTAssertEqual(back.layers, p.layers)
        // Old saves without the field still decode.
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        old.removeValue(forKey: "captionTracks")
        let oldP = try JSONDecoder().decode(Project.self, from: try JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(oldP.captionTracks)
    }

    func testCompWordsFollowTrimAndSpeed() {
        var p = project()
        var l = p.makeLayer(name: "v", content: .audio(fileName: "a.m4a", duration: 20), size: Vec2(10, 10))
        l.inPoint = 2; l.outPoint = 8; l.sourceStart = 4; l.speed = 2
        let out = CaptionTrack.compWords([w("x", 6, 7), w("gone", 1, 2)], for: l)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].start, 3, accuracy: 1e-9)
        XCTAssertEqual(out[0].end, 3.5, accuracy: 1e-9)
    }

    func testFakeTranscriberFeedsTrack() async throws {
        let fake = FakeTranscriber(words: sample)
        var got = 0.0
        let words = try await fake.transcribe(url: URL(fileURLWithPath: "/dev/null"), range: nil, localeID: "en-US") { got = $0 }
        var t = CaptionTrack(); t.setWords(words)
        XCTAssertEqual(got, 1)
        XCTAssertEqual(t.lines.count, 2)
    }
}
