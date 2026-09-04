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

    @MainActor
    func testBackendReadinessStartsStoppedBackend() async throws {
        let backend = ExplainVisibleBackendManagerStub(isRunning: false)

        try await ExplainVisibleBackendReadiness.ensureReady(using: backend)

        XCTAssertEqual(backend.startCallCount, 1)
        XCTAssertTrue(backend.isRunning)
    }

    @MainActor
    func testBackendReadinessLeavesRunningBackendAlone() async throws {
        let backend = ExplainVisibleBackendManagerStub(isRunning: true)

        try await ExplainVisibleBackendReadiness.ensureReady(using: backend)

        XCTAssertEqual(backend.startCallCount, 0)
    }

    @MainActor
    func testBackendReadinessSurfacesStartupFailure() async {
        let expected = NSError(
            domain: "ExplainVisibleTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Backend failed to start"]
        )
        let backend = ExplainVisibleBackendManagerStub(isRunning: false, startError: expected)

        do {
            try await ExplainVisibleBackendReadiness.ensureReady(using: backend)
            XCTFail("Expected backend startup to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Backend failed to start")
        }
    }
}

final class BackendStartupCoordinatorTests: XCTestCase {
    @MainActor
    func testDoesNotStartWithoutApprovedRepository() async {
        var startCount = 0
        let coordinator = BackendStartupCoordinator(
            startBackend: { startCount += 1 },
            afterSuccessfulStart: {}
        )

        await coordinator.startIfPossible(approvedPaths: [])

        XCTAssertEqual(startCount, 0)
        XCTAssertFalse(coordinator.didStart)
    }

    @MainActor
    func testSuccessfulStartupRunsOnlyOnce() async {
        var startCount = 0
        var successCount = 0
        let coordinator = BackendStartupCoordinator(
            startBackend: { startCount += 1 },
            afterSuccessfulStart: { successCount += 1 }
        )

        await coordinator.startIfPossible(approvedPaths: ["/repo"])
        await coordinator.startIfPossible(approvedPaths: ["/repo"])

        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(successCount, 1)
        XCTAssertTrue(coordinator.didStart)
    }

    @MainActor
    func testFailedStartupCanRetry() async {
        struct StartupFailure: Error {}
        var startCount = 0
        let coordinator = BackendStartupCoordinator(
            startBackend: {
                startCount += 1
                if startCount == 1 { throw StartupFailure() }
            },
            afterSuccessfulStart: {}
        )

        await coordinator.startIfPossible(approvedPaths: ["/repo"])
        await coordinator.startIfPossible(approvedPaths: ["/repo"])

        XCTAssertEqual(startCount, 2)
        XCTAssertTrue(coordinator.didStart)
    }

    @MainActor
    func testOverlappingStartupRequestsAreCoalesced() async {
        var startCount = 0
        let coordinator = BackendStartupCoordinator(
            startBackend: {
                startCount += 1
                try await Task.sleep(nanoseconds: 20_000_000)
            },
            afterSuccessfulStart: {}
        )

        async let first: Void = coordinator.startIfPossible(approvedPaths: ["/repo"])
        async let second: Void = coordinator.startIfPossible(approvedPaths: ["/repo"])
        _ = await (first, second)

        XCTAssertEqual(startCount, 1)
        XCTAssertTrue(coordinator.didStart)
    }
}

final class BackendPythonResolverTests: XCTestCase {
    func testPrefersExplicitOverride() {
        let resolved = BackendPythonResolver.resolve(
            backendDirectory: "/repo/backend",
            environment: ["REPOWHISPER_PYTHON_PATH": "/custom/python3.12"],
            fileExists: { $0 == "/custom/python3.12" }
        )
        XCTAssertEqual(resolved, "/custom/python3.12")
    }

    func testFindsDocumentedDotVenvBeforeLegacyVenv() {
        let existing = Set([
            "/repo/backend/.venv/bin/python3",
            "/repo/backend/venv/bin/python3",
        ])
        let resolved = BackendPythonResolver.resolve(
            backendDirectory: "/repo/backend",
            environment: [:],
            fileExists: { existing.contains($0) }
        )
        XCTAssertEqual(resolved, "/repo/backend/.venv/bin/python3")
    }

    func testRejectsUnsupportedSystemPythonFallback() {
        let resolved = BackendPythonResolver.resolve(
            backendDirectory: "/repo/backend",
            environment: [:],
            fileExists: { $0 == "/usr/bin/python3" }
        )
        XCTAssertNil(resolved)
    }
}

@MainActor
private final class ExplainVisibleBackendManagerStub: ExplainVisibleBackendManaging {
    var isRunning: Bool
    private let startError: Error?
    private(set) var startCallCount = 0

    init(isRunning: Bool, startError: Error? = nil) {
        self.isRunning = isRunning
        self.startError = startError
    }

    func start() async throws {
        startCallCount += 1
        if let startError { throw startError }
        isRunning = true
    }
}
