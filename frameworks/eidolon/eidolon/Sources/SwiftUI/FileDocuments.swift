import UIKit
import Foundation

public protocol FileDocument {
    static var readableContentTypes: [String] { get }
    static var writableContentTypes: [String] { get }

    init(configuration: FileDocumentReadConfiguration<Self>) throws
    func fileWrapper(configuration: FileDocumentWriteConfiguration<Self>) throws -> FileWrapper
}

public struct FileDocumentReadConfiguration<Document> {
    public var contentType: String
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
    public let existingFile: FileWrapper?

    public init(contentType: String, existingFile: FileWrapper? = nil) {
        self.contentType = contentType
        self.existingFile = existingFile
    }
}

extension FileDocument {
    init(contentsOf url: URL) throws {
        try self.init(configuration: FileDocumentReadConfiguration<Self>(
            contentType: Self.readableContentTypes.first ?? "public.data",
            file: try Data(contentsOf: url), fileURL: url))
    }
}

public struct FileDocumentConfiguration<Document> where Document: FileDocument {
    @Binding public var document: Document
    public var fileURL: URL?
    public var isEditable: Bool

    public init(document: Binding<Document>, fileURL: URL? = nil, isEditable: Bool = true) {
        self._document = document
        self.fileURL = fileURL
        self.isEditable = isEditable
    }
}

public protocol ReferenceFileDocument: ObservableObject {
    static var readableContentTypes: [String] { get }
    static var writableContentTypes: [String] { get }

    var data: Data { get set }
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

    func newDocumentView() -> Content? {
        guard let newDocument else { return nil }
        return viewer(FileDocumentConfiguration(document: Binding(get: { newDocument() },
                                                                 set: { _ in }),
                                                fileURL: nil, isEditable: true))
    }
}
