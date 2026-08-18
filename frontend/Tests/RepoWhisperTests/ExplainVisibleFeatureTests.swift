import XCTest
@testable import RepoWhisper

final class ExplainVisibleFeatureTests: XCTestCase {
    func testOCRIdentifierExtractionPrioritizesDeclarations() {
        let text = "func calculateOrbitalLatency(distance: Double) -> Double"
        let identifiers = VisibleCodeIdentifierExtractor.identifiers(in: text)
        XCTAssertEqual(identifiers.first, "calculateOrbitalLatency")
        XCTAssertTrue(identifiers.contains("distance"))
    }

    func testRequestEncodingUsesBackendKeys() throws {
        let request = ExplainVisibleRequest(
            ocrText: "calculate_total",
            recentTranscript: nil,
            selectedText: nil,
            repoId: "repo-a",
            visibleApp: "Xcode",
            topKCandidates: 5
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertEqual(object["ocr_text"] as? String, "calculate_total")
        XCTAssertEqual(object["repo_id"] as? String, "repo-a")
        XCTAssertEqual(object["top_k_candidates"] as? Int, 5)
    }

    func testResponseDecoding() throws {
        let json = #"""
        {
          "matched_symbol":{"name":"calculate_total","kind":"function","repo_id":"repo-a","file_path":"/repo/math.py","line_start":4,"line_end":14,"confidence":0.94},
          "candidate_symbols":[],
          "explanation":{"summary":"Totals values.","purpose":"Appears to centralize totals.","purpose_is_inference":true,"how_it_works":["Sums values"],"inputs":["values"],"outputs":["total"],"side_effects":[],"dependencies":[],"callers":[],"risks_and_questions":[]},
          "sources":[{"file_path":"/repo/math.py","line_start":4,"line_end":14,"reason":"Primary implementation"}],
          "transcript_context_used":false,
          "latency_ms":12.5
        }
        """#.data(using: .utf8)!
        let response = try JSONDecoder().decode(ExplainVisibleResponse.self, from: json)
        XCTAssertEqual(response.matchedSymbol?.name, "calculate_total")
        XCTAssertEqual(response.explanation?.summary, "Totals values.")
        XCTAssertEqual(response.sources.first?.lineStart, 4)
    }

    func testStateTransitionsCoverLoadingSuccessAndError() {
        var machine = ExplainVisibleStateMachine()
        machine.send(.startCapture)
        XCTAssertEqual(machine.state, .capturing)
        machine.send(.ocrFinished)
        XCTAssertEqual(machine.state, .matching)
        machine.send(.requestFinished(.fixture))
        XCTAssertEqual(machine.state, .success(.fixture))
        machine.send(.failed("Provider is not configured"))
        XCTAssertEqual(machine.state, .error("Provider is not configured"))
    }

    func testLowConfidenceCandidatesRequireSelection() {
        var response = ExplainVisibleResponse.fixture
        response.matchedSymbol = nil
        response.candidateSymbols = [.fixture, .fixture]
        response.explanation = nil
        XCTAssertTrue(response.requiresCandidateSelection)
    }

    func testBackendProviderErrorIsUserVisible() {
        let error = APIError.serverError("Configure an explanation provider in Settings.")
        XCTAssertEqual(
            error.localizedDescription,
            "Configure an explanation provider in Settings."
        )
    }
}
