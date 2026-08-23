import AppKit
import Foundation
import Vision

struct VisibleScreenCapture {
    let imageData: Data
    let visibleApp: String?
}

enum ExplainVisibleFeatureError: LocalizedError {
    case screenPermissionDenied
    case screenCaptureFailed
    case noVisibleCode

    var errorDescription: String? {
        switch self {
        case .screenPermissionDenied:
            return "Screen Recording permission is required to explain visible code."
        case .screenCaptureFailed:
            return "RepoWhisper could not capture the visible editor window."
        case .noVisibleCode:
            return "No code identifiers were detected. Put the function on screen and try again."
        }
    }
}

enum VisibleCodeIdentifierExtractor {
    private static let declarationPattern = #"(?m)^\s*(?:(?:public|private|internal|protected|static|async|export)\s+)*(?:def|func|function|class|struct|enum|protocol|actor|interface)\s+([A-Za-z_][A-Za-z0-9_]*)"#
    private static let identifierPattern = #"\b[A-Za-z_][A-Za-z0-9_]{2,}\b"#
    private static let ignored: Set<String> = [
        "actor", "async", "await", "class", "def", "else", "enum", "false",
        "func", "function", "guard", "import", "interface", "internal", "let",
        "none", "null", "private", "protocol", "public", "return", "static",
        "struct", "throw", "throws", "true", "var", "while"
    ]

    static func identifiers(in text: String) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        let range = NSRange(text.startIndex..., in: text)

        if let regex = try? NSRegularExpression(pattern: declarationPattern) {
            for match in regex.matches(in: text, range: range) {
                guard let swiftRange = Range(match.range(at: 1), in: text) else { continue }
                let name = String(text[swiftRange])
                if seen.insert(name).inserted { ordered.append(name) }
            }
        }
        if let regex = try? NSRegularExpression(pattern: identifierPattern) {
            for match in regex.matches(in: text, range: range) {
                guard let swiftRange = Range(match.range, in: text) else { continue }
                let name = String(text[swiftRange])
                guard !ignored.contains(name.lowercased()) else { continue }
                if seen.insert(name).inserted { ordered.append(name) }
            }
        }
        return Array(ordered.prefix(200))
    }
}

struct VisionOCRService {
    func recognizeCode(in imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try handler.perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}

struct ExplainVisibleRequest: Codable, Equatable {
    let ocrText: String
    let recentTranscript: String?
    let selectedText: String?
    let repoId: String?
    let visibleApp: String?
    let topKCandidates: Int

    enum CodingKeys: String, CodingKey {
        case ocrText = "ocr_text"
        case recentTranscript = "recent_transcript"
        case selectedText = "selected_text"
        case repoId = "repo_id"
        case visibleApp = "visible_app"
        case topKCandidates = "top_k_candidates"
    }
}

struct ExplainVisibleSymbol: Codable, Equatable, Identifiable {
    let name: String
    let kind: String
    let repoId: String
    let filePath: String
    let lineStart: Int
    let lineEnd: Int
    let confidence: Double

    var id: String { "\(repoId):\(filePath):\(lineStart):\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, kind, confidence
        case repoId = "repo_id"
        case filePath = "file_path"
        case lineStart = "line_start"
        case lineEnd = "line_end"
    }
}

struct CodeExplanation: Codable, Equatable {
    let summary: String
    let purpose: String
    let purposeIsInference: Bool
    let howItWorks: [String]
    let inputs: [String]
    let outputs: [String]
    let sideEffects: [String]
    let dependencies: [String]
    let callers: [String]
    let risksAndQuestions: [String]

    enum CodingKeys: String, CodingKey {
        case summary, purpose, inputs, outputs, dependencies, callers
        case purposeIsInference = "purpose_is_inference"
        case howItWorks = "how_it_works"
        case sideEffects = "side_effects"
        case risksAndQuestions = "risks_and_questions"
    }
}

struct ExplainVisibleSource: Codable, Equatable, Identifiable {
    let filePath: String
    let lineStart: Int
    let lineEnd: Int
    let reason: String

    var id: String { "\(filePath):\(lineStart):\(reason)" }

    enum CodingKeys: String, CodingKey {
        case reason
        case filePath = "file_path"
        case lineStart = "line_start"
        case lineEnd = "line_end"
    }
}

struct ExplainVisibleResponse: Codable, Equatable {
    var matchedSymbol: ExplainVisibleSymbol?
    var candidateSymbols: [ExplainVisibleSymbol]
    var explanation: CodeExplanation?
    var sources: [ExplainVisibleSource]
    let transcriptContextUsed: Bool
    let latencyMs: Double

    var requiresCandidateSelection: Bool {
        matchedSymbol == nil && explanation == nil && !candidateSymbols.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case matchedSymbol = "matched_symbol"
        case candidateSymbols = "candidate_symbols"
        case explanation, sources
        case transcriptContextUsed = "transcript_context_used"
        case latencyMs = "latency_ms"
    }
}

extension ExplainVisibleSymbol {
    static let fixture = ExplainVisibleSymbol(
        name: "calculate_total", kind: "function", repoId: "repo-a",
        filePath: "/repo/math.py", lineStart: 4, lineEnd: 14, confidence: 0.94
    )
}

extension ExplainVisibleResponse {
    static let fixture = ExplainVisibleResponse(
        matchedSymbol: .fixture,
        candidateSymbols: [],
        explanation: nil,
        sources: [],
        transcriptContextUsed: false,
        latencyMs: 1
    )
}

enum ExplainVisibleStage: String, Equatable {
    case capturing = "Capturing visible code…"
    case matching = "Matching repository symbols…"
    case gathering = "Gathering callers and dependencies…"
    case generating = "Generating explanation…"
}

enum ExplainVisibleState: Equatable {
    case idle
    case capturing
    case matching
    case gathering
    case generating
    case candidates(ExplainVisibleResponse)
    case success(ExplainVisibleResponse)
    case error(String)
}

struct ExplainVisibleStateMachine {
    enum Event {
        case startCapture
        case ocrFinished
        case gatheringContext
        case generatingExplanation
        case requestFinished(ExplainVisibleResponse)
        case failed(String)
    }

    private(set) var state: ExplainVisibleState = .idle

    mutating func send(_ event: Event) {
        switch event {
        case .startCapture: state = .capturing
        case .ocrFinished: state = .matching
        case .gatheringContext: state = .gathering
        case .generatingExplanation: state = .generating
        case .requestFinished(let response):
            state = response.requiresCandidateSelection ? .candidates(response) : .success(response)
        case .failed(let message): state = .error(message)
        }
    }
}

@MainActor
protocol ExplainVisibleBackendManaging: AnyObject {
    var isRunning: Bool { get }
    func start() async throws
}

extension BackendProcessManager: ExplainVisibleBackendManaging {}

@MainActor
enum ExplainVisibleBackendReadiness {
    static func ensureReady(using backend: any ExplainVisibleBackendManaging) async throws {
        guard !backend.isRunning else { return }
        try await backend.start()
    }
}

@MainActor
final class ExplainVisibleCoordinator: ObservableObject {
    static let shared = ExplainVisibleCoordinator()

    @Published private(set) var state: ExplainVisibleState = .idle
    private var machine = ExplainVisibleStateMachine()
    private var lastOCRText = ""
    private var lastVisibleApp: String?

    var isWorking: Bool {
        switch state {
        case .capturing, .matching, .gathering, .generating: return true
        default: return false
        }
    }

    func explain(selectedText: String? = nil, repoId: String? = nil) async {
        send(.startCapture)
        FloatingPopupManager.shared.hidePopup()

        do {
            try await ExplainVisibleBackendReadiness.ensureReady(
                using: BackendProcessManager.shared
            )
            let capture = try await ScreenshotCapture.shared.captureVisibleScreen()
            let ocrText = try await VisionOCRService().recognizeCode(in: capture.imageData)
            guard !VisibleCodeIdentifierExtractor.identifiers(
                in: [selectedText, ocrText].compactMap { $0 }.joined(separator: "\n")
            ).isEmpty else {
                throw ExplainVisibleFeatureError.noVisibleCode
            }
            lastOCRText = ocrText
            lastVisibleApp = capture.visibleApp
            try await requestExplanation(
                ocrText: ocrText,
                selectedText: selectedText,
                repoId: repoId,
                visibleApp: capture.visibleApp
            )
        } catch {
            fail(error)
        }
    }

    func selectCandidate(_ candidate: ExplainVisibleSymbol) async {
        do {
            try await requestExplanation(
                ocrText: lastOCRText,
                selectedText: candidate.name,
                repoId: candidate.repoId,
                visibleApp: lastVisibleApp
            )
        } catch {
            fail(error)
        }
    }

    private func requestExplanation(
        ocrText: String,
        selectedText: String?,
        repoId: String?,
        visibleApp: String?
    ) async throws {
        send(.ocrFinished)
        FloatingPopupManager.shared.showExplainStage(.matching)
        send(.gatheringContext)

        let request = ExplainVisibleRequest(
            ocrText: ocrText,
            recentTranscript: nil,
            selectedText: selectedText,
            repoId: repoId,
            visibleApp: visibleApp,
            topKCandidates: 5
        )
        send(.generatingExplanation)
        let response = try await APIClient.shared.explainVisibleCode(request)
        send(.requestFinished(response))
        FloatingPopupManager.shared.showExplainResult(response)
    }

    private func send(_ event: ExplainVisibleStateMachine.Event) {
        machine.send(event)
        state = machine.state
    }

    private func fail(_ error: Error) {
        let message = error.localizedDescription
        send(.failed(message))
        FloatingPopupManager.shared.showErrorToast(message)
        FloatingPopupManager.shared.showExplainError(message)
    }
}
