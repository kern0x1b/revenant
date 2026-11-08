import Foundation

@available(iOS 18.0, *)
public class LanguageAvailability {
    public enum Status: Hashable, Sendable {
        case installed
        case supported
        case unsupported
    }

    public var supportedLanguages: [Locale.Language] {
        get async {
            return []
        }
    }

    public func status(from source: Locale.Language, to target: Locale.Language?) async -> Status {
        return .unsupported
    }

    public func status(for text: String, to target: Locale.Language?) async throws -> Status {
        return .unsupported
    }

    public init() {
    }
}

@available(iOS 18.0, *)
public struct TranslationError: LocalizedError {
    private enum Kind {
        case unsupportedSourceLanguage
        case unsupportedTargetLanguage
        case unsupportedLanguagePairing
        case unableToIdentifyLanguage
        case nothingToTranslate
        case alreadyCancelled
        case notInstalled
        case internalError
    }

    private let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
    }

    public static let unsupportedSourceLanguage = TranslationError(.unsupportedSourceLanguage)
    public static let unsupportedTargetLanguage = TranslationError(.unsupportedTargetLanguage)
    public static let unsupportedLanguagePairing = TranslationError(.unsupportedLanguagePairing)
    public static let unableToIdentifyLanguage = TranslationError(.unableToIdentifyLanguage)
    public static let nothingToTranslate = TranslationError(.nothingToTranslate)

    @available(iOS 26.0, *)
    public static let alreadyCancelled = TranslationError(.alreadyCancelled)

    @available(iOS 26.0, *)
    public static let notInstalled = TranslationError(.notInstalled)

    public static let internalError = TranslationError(.internalError)

    public static func ~= (match: TranslationError, error: any Error) -> Bool {
        guard let other = error as? TranslationError else {
            return false
        }
        return other.kind == match.kind
    }

    public var errorDescription: String? {
        switch kind {
        case .unsupportedSourceLanguage:
            return "Unsupported source language"
        case .unsupportedTargetLanguage:
            return "Unsupported target language"
        case .unsupportedLanguagePairing:
            return "Unsupported language pairing"
        case .unableToIdentifyLanguage:
            return "Unable to identify the language"
        case .nothingToTranslate:
            return "Nothing to translate"
        case .alreadyCancelled:
            return "The translation was already cancelled"
        case .notInstalled:
            return "The language is not installed"
        case .internalError:
            return "Internal translation error"
        }
    }

    public var failureReason: String? {
        switch kind {
        case .unsupportedSourceLanguage:
            return "This system has no translation model for the source language."
        case .unsupportedTargetLanguage:
            return "This system has no translation model for the target language."
        case .unsupportedLanguagePairing:
            return "This system has no translation service, so it translates between no pair of languages."
        case .unableToIdentifyLanguage:
            return "The language of the text could not be identified."
        case .nothingToTranslate:
            return "The text to translate is empty."
        case .alreadyCancelled:
            return "The session was cancelled before the request."
        case .notInstalled:
            return "The language assets are not installed on this system."
        case .internalError:
            return "The translation service failed."
        }
    }
}

@available(iOS 18.0, *)
public class TranslationSession {
    final public let sourceLanguage: Locale.Language?
    final public let targetLanguage: Locale.Language?

    init(source: Locale.Language?, target: Locale.Language?) {
        self.sourceLanguage = source
        self.targetLanguage = target
    }

    @available(iOS 26.0, *)
    public convenience init(installedSource source: Locale.Language, target: Locale.Language?) {
        self.init(source: source, target: target)
    }

    @available(iOS 26.0, *)
    public var canRequestDownloads: Bool {
        return false
    }

    @available(iOS 26.0, *)
    public var isReady: Bool {
        get async {
            return false
        }
    }

    public struct Request {
        public var sourceText: String
        public var clientIdentifier: String?

        public init(sourceText: String, clientIdentifier: String? = nil) {
            self.sourceText = sourceText
            self.clientIdentifier = clientIdentifier
        }
    }

    public struct Response: Sendable {
        public let sourceLanguage: Locale.Language
        public let targetLanguage: Locale.Language
        public let sourceText: String
        public let targetText: String
        public let clientIdentifier: String?

        public init(sourceLanguage: Locale.Language, targetLanguage: Locale.Language, sourceText: String, targetText: String, clientIdentifier: String? = nil) {
            self.sourceLanguage = sourceLanguage
            self.targetLanguage = targetLanguage
            self.sourceText = sourceText
            self.targetText = targetText
            self.clientIdentifier = clientIdentifier
        }
    }

    public struct BatchResponse: AsyncSequence {
        public typealias Element = TranslationSession.Response

        fileprivate let refusals: [TranslationError]

        public func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(refusals: refusals)
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = TranslationSession.BatchResponse.Element

            fileprivate var refusals: [TranslationError]

            public mutating func next() async throws -> TranslationSession.BatchResponse.Element? {
                guard let refusal = refusals.first else {
                    return nil
                }
                refusals = []
                throw refusal
            }
        }
    }

    public struct Configuration: Equatable {
        public var source: Locale.Language?
        public var target: Locale.Language?
        public private(set) var version: Int = 0

        public mutating func invalidate() {
            version += 1
        }

        public init(source: Locale.Language? = nil, target: Locale.Language? = nil) {
            self.source = source
            self.target = target
        }
    }

    private func refusal(for text: String) -> TranslationError {
        return text.isEmpty ? .nothingToTranslate : .unsupportedLanguagePairing
    }

    public func translate(_ string: String) async throws -> Response {
        throw refusal(for: string)
    }

    public func translate(batch: [Request]) -> BatchResponse {
        return BatchResponse(refusals: batch.map { refusal(for: $0.sourceText) })
    }

    public func translations(from batch: [Request]) async throws -> [Response] {
        if let first = batch.first {
            throw refusal(for: first.sourceText)
        }
        return []
    }

    public func prepareTranslation() async throws {
        throw TranslationError.unsupportedLanguagePairing
    }

    @available(iOS 26.0, *)
    public func cancel() {
    }
}
