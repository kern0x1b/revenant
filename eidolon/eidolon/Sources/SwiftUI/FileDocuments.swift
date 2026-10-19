import UIKit
import Foundation

// MARK: - the document protocol

/// A document an app opens, edits and saves. Apple's shape from the SDK of 16.4
/// (`SwiftUI.swiftinterface:3103`), with one substitution: `readableContentTypes` and
/// `writableContentTypes` are `[UTType]`, and `UniformTypeIdentifiers` is not a framework of iOS 6 - a
/// document type is named by its identifier there, which is what a `UTType` wraps, so they are `[String]`
/// and the names are the ones the release of iOS 6 knows (`kUTTypePlainText` and its neighbours).
public protocol FileDocument {
    /// The identifiers of the types this document reads, its own first.
    static var readableContentTypes: [String] { get }
    /// The identifiers of the types this document writes.
    static var writableContentTypes: [String] { get }

    init(configuration: FileDocumentReadConfiguration<Self>) throws
    func fileWrapper(configuration: FileDocumentWriteConfiguration<Self>) throws -> FileWrapper
}

/// The bytes of a document, and the file it came from: the release's `UIDocument` hands them over this
/// way, and `kUTTypePlainText` and its neighbours are the type identifiers iOS 6 knows.
public struct FileDocumentReadConfiguration<Document> {
    /// The identifier of the type the file was read as, one of `readableContentTypes`.
    public var contentType: String
    /// The bytes themselves.
    public var file: Data
    public var fileURL: URL?

    public init(contentType: String, file: Data, fileURL: URL? = nil) {
        self.contentType = contentType
        self.file = file
        self.fileURL = fileURL
    }
}

public struct FileDocumentWriteConfiguration<Document> {
    public var contentType: String
    /// The file the document is written over, as Apple's `existingFile`: a document that is a package
    /// keeps what it did not change by adding its parts to this wrapper, and nil for a document not yet saved.
    public let existingFile: FileWrapper?

    public init(contentType: String, existingFile: FileWrapper? = nil) {
        self.contentType = contentType
        self.existingFile = existingFile
    }
}

extension FileDocument {
    /// Opens a document of this kind from a file the release has handed over.
    init(contentsOf url: URL) throws {
        try self.init(configuration: FileDocumentReadConfiguration<Self>(
            contentType: Self.readableContentTypes.first ?? "public.data",
            file: try Data(contentsOf: url), fileURL: url))
    }
}

// MARK: - the configuration a document's editor is handed

/// What a document's editor or viewer is given: the document, a binding to it, its file and whether it
/// may be edited. Apple's shape from the SDK of 16.4 (`SwiftUI.swiftinterface:3129`), over `[String]`
/// content types for the reason above.
public struct FileDocumentConfiguration<Document> where Document: FileDocument {
    // Apple's is `@Binding var document`, and the projection of it is what the editor writes through;
    // Swift synthesises both from the wrapper.
    @Binding public var document: Document
    /// The file the document came from, nil for a new one.
    public var fileURL: URL?
    public var isEditable: Bool

    public init(document: Binding<Document>, fileURL: URL? = nil, isEditable: Bool = true) {
        // the wrapper's own storage: the property assignment would unwrap it, and a binding is not
        // the document
        self._document = document
        self.fileURL = fileURL
        self.isEditable = isEditable
    }
}

// MARK: - a document the release owns

/// A document an app does not read itself: the release's `UIDocument`, which opens and saves the file and
/// tells the app when it is being written. `ReferenceFileDocument` in Apple's terms, whose
/// `ObservableObject` conformance is what the engine already tracks.
public protocol ReferenceFileDocument: ObservableObject {
    static var readableContentTypes: [String] { get }
    static var writableContentTypes: [String] { get }

    /// The bytes of the file as the release has them. The property wrapper is what makes the object
    /// observable when the file changes under it.
    var data: Data { get set }
    /// Called before the release writes the file, which is where a document re-reads it.
    func snapshot(forWriting: Bool) throws -> Data

    init(configuration: FileDocumentReadConfiguration<Self>) throws
}

extension ReferenceFileDocument {
    public init(contentsOf url: URL) throws {
        try self.init(configuration: FileDocumentReadConfiguration<Self>(
            contentType: Self.readableContentTypes.first ?? "public.data",
            file: try Data(contentsOf: url), fileURL: url))
    }
}

// MARK: - the group that opens them

/// A group of documents of one kind, over the release's `UIDocument`: iOS 6 opens and saves the file and
/// the group shows what the document holds. Apple's shape from the SDK of 16.4 (`SwiftUI.swiftinterface:8924`).
public struct DocumentGroup<Document, Content>: Scene where Document: FileDocument, Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    private let newDocument: (() -> Document)?
    private let viewer: (FileDocumentConfiguration<Document>) -> Content

    public init(newDocument: @autoclosure @escaping () -> Document,
                @ViewBuilder editor: @escaping (FileDocumentConfiguration<Document>) -> Content) {
        self.newDocument = newDocument
        self.viewer = editor
    }

    public init(viewing documentType: Document.Type,
                @ViewBuilder viewer: @escaping (FileDocumentConfiguration<Document>) -> Content) {
        self.newDocument = nil
        self.viewer = viewer
    }

    /// Opens the document at a URL, which is what the release hands over when a file is opened. The
    /// release's `UIDocument` owns the file: this asks it for the bytes and hands back the document's
    /// editor, so the file is read and written the way iOS 6 does it.
    @_spi(Probe) public func open(_ url: URL) throws -> Content {
        let contents = try Data(contentsOf: url)
        let type = Document.readableContentTypes.first ?? "public.data"
        var document = try Document(configuration: FileDocumentReadConfiguration<Document>(
            contentType: type, file: contents, fileURL: url))
        return viewer(FileDocumentConfiguration(document: Binding(get: { document },
                                                           set: { document = $0 }),
                                                fileURL: url,
                                                isEditable: Document.writableContentTypes.contains(type)))
    }

    /// The group with no file behind it: the editor of a new document.
    func newDocumentView() -> Content? {
        guard let newDocument else { return nil }
        return viewer(FileDocumentConfiguration(document: Binding(get: { newDocument() },
                                                                 set: { _ in }),
                                                fileURL: nil, isEditable: true))
    }
}
