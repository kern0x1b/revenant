// The system schemas: the intents, entities and enums that belong to the system rather than to an app -
// Books, Mail, Photos, Safari, Files and the rest - named by the identifier the framework's own index
// knows them by.
//
// A schema is a name and nothing more: it is what a system intent is keyed by, and what the port's own
// store of donations and shortcuts is written against. The system apps these name are not on the
// releases this port builds for, so `AssistantSchema.IntentSchema("OpenURLInTabIntent")` is the real value
// here - and it is the framework's own answer as well: the schema of an intent whose app is absent is
// still its name. What is missing is the app behind the name, and that is the app's own to provide; a
// port's own intent does not go through a schema at all. `facts/AppIntents/Services.md` says so.

import Foundation

/// A schema value that names itself, which is what the concrete schema types answer and what a
/// caller reads the identifier of.
public protocol CharonNamedSchema {
    /// The name the framework's index knows this system intent, entity or enum by.
    var identifier: String { get }
}

/// A schema: the name the framework's own index knows a system intent, entity or enum by.
public struct AssistantSchema: Sendable {
    /// The name this schema is known by.
    public let identifier: String

    public init(_ schema: String) {
        self.identifier = schema
    }

    /// The schema of a system intent, which is what an intent's own `schema` names.
    public typealias IntentSchema = AssistantSchemas.IntentSchema

    /// The schema of a system entity, which is what an entity's own `schema` names.
    public typealias EntitySchema = AssistantSchemas.EntitySchema

    /// The schema of a system enum, which is what an enum's own `schema` names.
    public typealias EnumSchema = AssistantSchemas.EnumSchema
}

/// The three concrete schema types, one for each kind of model: what `AssistantSchemas.Intent`,
/// `AssistantSchemas.Entity` and `AssistantSchemas.Enum` answer when the app names a schema.
extension AssistantSchemas {
    /// A system intent's schema: the value the framework's index holds for the intent.
    public struct IntentSchema: CharonNamedSchema {
        /// The name the schema is known by.
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
    /// A system entity's schema: the value the framework's index holds for the entity.
    public struct EntitySchema: CharonNamedSchema {
        /// The name the schema is known by.
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
    /// A system enum's schema: the value the framework's index holds for the enum.
    public struct EnumSchema: CharonNamedSchema {
        /// The name the schema is known by.
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
}

/// The system schemas: what the system names, and of which kind.
public enum AssistantSchemas {
    /// Anything the system names: an intent, an entity or an enum.
    @_marker public protocol Model {}

    /// A system intent.
    @_marker public protocol Intent: Model {}

    /// A system entity.
    @_marker public protocol Entity: Model {}

    /// A system enum.
    @_marker public protocol Enum: Model {}

    /// A system intent of the ReaderIntent family, the kind the framework's index groups it under.
    @_marker public protocol ReaderIntent: Intent {}
    /// A system intent of the FilesIntent family, the kind the framework's index groups it under.
    @_marker public protocol FilesIntent: Intent {}
    /// A system intent of the PresentationIntent family, the kind the framework's index groups it under.
    @_marker public protocol PresentationIntent: Intent {}
    /// A system intent of the MailIntent family, the kind the framework's index groups it under.
    @_marker public protocol MailIntent: Intent {}
    /// A system intent of the VisualIntelligenceIntent family, the kind the framework's index groups it under.
    @_marker public protocol VisualIntelligenceIntent: Intent {}
    /// A system intent of the BrowserIntent family, the kind the framework's index groups it under.
    @_marker public protocol BrowserIntent: Intent {}
    /// A system intent of the SpreadsheetIntent family, the kind the framework's index groups it under.
    @_marker public protocol SpreadsheetIntent: Intent {}
    /// A system intent of the PhotosIntent family, the kind the framework's index groups it under.
    @_marker public protocol PhotosIntent: Intent {}
    /// A system intent of the BooksIntent family, the kind the framework's index groups it under.
    @_marker public protocol BooksIntent: Intent {}
    /// A system intent of the CameraIntent family, the kind the framework's index groups it under.
    @_marker public protocol CameraIntent: Intent {}
    /// A system intent of the AssistantIntent family, the kind the framework's index groups it under.
    @_marker public protocol AssistantIntent: Intent {}
    /// A system intent of the SystemIntent family, the kind the framework's index groups it under.
    @_marker public protocol SystemIntent: Intent {}
    /// A system intent of the WordProcessorIntent family, the kind the framework's index groups it under.
    @_marker public protocol WordProcessorIntent: Intent {}
    /// A system intent of the WhiteboardIntent family, the kind the framework's index groups it under.
    @_marker public protocol WhiteboardIntent: Intent {}
    /// A system intent of the JournalIntent family, the kind the framework's index groups it under.
    @_marker public protocol JournalIntent: Intent {}
    /// A system entity of the ReaderEntity family, the kind the framework's index groups it under.
    @_marker public protocol ReaderEntity: Entity {}
    /// A system entity of the FilesEntity family, the kind the framework's index groups it under.
    @_marker public protocol FilesEntity: Entity {}
    /// A system entity of the PresentationEntity family, the kind the framework's index groups it under.
    @_marker public protocol PresentationEntity: Entity {}
    /// A system entity of the MailEntity family, the kind the framework's index groups it under.
    @_marker public protocol MailEntity: Entity {}
    /// A system entity of the BrowserEntity family, the kind the framework's index groups it under.
    @_marker public protocol BrowserEntity: Entity {}
    /// A system entity of the SpreadsheetEntity family, the kind the framework's index groups it under.
    @_marker public protocol SpreadsheetEntity: Entity {}
    /// A system entity of the PhotosEntity family, the kind the framework's index groups it under.
    @_marker public protocol PhotosEntity: Entity {}
    /// A system entity of the BooksEntity family, the kind the framework's index groups it under.
    @_marker public protocol BooksEntity: Entity {}
    /// A system entity of the WordProcessorEntity family, the kind the framework's index groups it under.
    @_marker public protocol WordProcessorEntity: Entity {}
    /// A system entity of the WhiteboardEntity family, the kind the framework's index groups it under.
    @_marker public protocol WhiteboardEntity: Entity {}
    /// A system entity of the JournalEntity family, the kind the framework's index groups it under.
    @_marker public protocol JournalEntity: Entity {}
    /// A system enum of the ReaderEnum family, the kind the framework's index groups it under.
    @_marker public protocol ReaderEnum: Enum {}
    /// A system enum of the BrowserEnum family, the kind the framework's index groups it under.
    @_marker public protocol BrowserEnum: Enum {}
    /// A system enum of the PhotosEnum family, the kind the framework's index groups it under.
    @_marker public protocol PhotosEnum: Enum {}
    /// A system enum of the BooksEnum family, the kind the framework's index groups it under.
    @_marker public protocol BooksEnum: Enum {}
    /// A system enum of the _AppShortcutsContentMarker family, the kind the framework's index groups it under.
    @_marker public protocol _AppShortcutsContentMarker: Enum {}
    /// A system enum of the _AppShortcutsContentEmitterMarker family, the kind the framework's index groups it under.
    @_marker public protocol _AppShortcutsContentEmitterMarker: Enum {}
    /// A system enum of the _LimitedAvailabilityAppShortcutsContentMarker family, the kind the framework's index groups it under.
    @_marker public protocol _LimitedAvailabilityAppShortcutsContentMarker: Enum {}
    /// A system enum of the CameraEnum family, the kind the framework's index groups it under.
    @_marker public protocol CameraEnum: Enum {}
    /// A system enum of the WhiteboardEnum family, the kind the framework's index groups it under.
    @_marker public protocol WhiteboardEnum: Enum {}
}


extension AssistantSchemas.IntentSchema: AssistantSchemas.Model {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.ReaderIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.FilesIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.PresentationIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.MailIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.VisualIntelligenceIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.BrowserIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.SpreadsheetIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.PhotosIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.BooksIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.CameraIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.AssistantIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.SystemIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.WordProcessorIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.WhiteboardIntent {}
extension AssistantSchemas.IntentSchema: AssistantSchemas.JournalIntent {}

extension AssistantSchemas.EntitySchema: AssistantSchemas.Entity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.Model {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.ReaderEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.FilesEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.PresentationEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.MailEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.BrowserEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.SpreadsheetEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.PhotosEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.BooksEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.WordProcessorEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.WhiteboardEntity {}
extension AssistantSchemas.EntitySchema: AssistantSchemas.JournalEntity {}

extension AssistantSchemas.EnumSchema: AssistantSchemas.Enum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.Model {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.ReaderEnum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.BrowserEnum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.PhotosEnum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.BooksEnum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas._AppShortcutsContentMarker {}
extension AssistantSchemas.EnumSchema: AssistantSchemas._AppShortcutsContentEmitterMarker {}
extension AssistantSchemas.EnumSchema: AssistantSchemas._LimitedAvailabilityAppShortcutsContentMarker {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.CameraEnum {}
extension AssistantSchemas.EnumSchema: AssistantSchemas.WhiteboardEnum {}

extension AssistantSchemas.Intent where Self == AssistantSchemas.IntentSchema {
    /// The system intent `reader`, which the framework's index knows as `reader`.
    public static var reader: some AssistantSchemas.ReaderIntent {
        return AssistantSchema.IntentSchema("reader")
    }

    /// The system intent `files`, which the framework's index knows as `files`.
    public static var files: some AssistantSchemas.FilesIntent {
        return AssistantSchema.IntentSchema("files")
    }

    /// The system intent `presentation`, which the framework's index knows as `com.apple.Presentation`.
    public static var presentation: some AssistantSchemas.PresentationIntent {
        return AssistantSchema.IntentSchema("com.apple.Presentation")
    }

    /// The system intent `mail`, which the framework's index knows as `mail`.
    public static var mail: some AssistantSchemas.MailIntent {
        return AssistantSchema.IntentSchema("mail")
    }

    /// The system intent `visualIntelligence`, which the framework's index knows as `visualIntelligence`.
    public static var visualIntelligence: some AssistantSchemas.VisualIntelligenceIntent {
        return AssistantSchema.IntentSchema("visualIntelligence")
    }

    /// The system intent `browser`, which the framework's index knows as `Intent`.
    public static var browser: some AssistantSchemas.BrowserIntent {
        return AssistantSchema.IntentSchema("Intent")
    }

    /// The system intent `spreadsheet`, which the framework's index knows as `spreadsheet`.
    public static var spreadsheet: some AssistantSchemas.SpreadsheetIntent {
        return AssistantSchema.IntentSchema("spreadsheet")
    }

    /// The system intent `photos`, which the framework's index knows as `photos`.
    public static var photos: some AssistantSchemas.PhotosIntent {
        return AssistantSchema.IntentSchema("photos")
    }

    /// The system intent `books`, which the framework's index knows as `books`.
    public static var books: some AssistantSchemas.BooksIntent {
        return AssistantSchema.IntentSchema("books")
    }

    /// The system intent `camera`, which the framework's index knows as `camera`.
    public static var camera: some AssistantSchemas.CameraIntent {
        return AssistantSchema.IntentSchema("camera")
    }

    /// The system intent `assistant`, which the framework's index knows as `assistant`.
    public static var assistant: some AssistantSchemas.AssistantIntent {
        return AssistantSchema.IntentSchema("assistant")
    }

    /// The system intent `system`, which the framework's index knows as `system`.
    public static var system: some AssistantSchemas.SystemIntent {
        return AssistantSchema.IntentSchema("system")
    }

    /// The system intent `wordProcessor`, which the framework's index knows as `wordProcessor`.
    public static var wordProcessor: some AssistantSchemas.WordProcessorIntent {
        return AssistantSchema.IntentSchema("wordProcessor")
    }

    /// The system intent `whiteboard`, which the framework's index knows as `whiteboard`.
    public static var whiteboard: some AssistantSchemas.WhiteboardIntent {
        return AssistantSchema.IntentSchema("whiteboard")
    }

    /// The system intent `journal`, which the framework's index knows as `journal`.
    public static var journal: some AssistantSchemas.JournalIntent {
        return AssistantSchema.IntentSchema("journal")
    }

}

extension AssistantSchemas.ReaderIntent {
    /// The system intent `rotateDocuments`, which the framework's index knows as `ReaderRotateDocumentsIntent`.
    public static var rotateDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderRotateDocumentsIntent")
    }

    /// The system intent `resizeDocuments`, which the framework's index knows as `ReaderResizeDocumentsIntent`.
    public static var resizeDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderResizeDocumentsIntent")
    }

    /// The system intent `openPage`, which the framework's index knows as `ReaderOpenPageIntent`.
    public static var openPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderOpenPageIntent")
    }

    /// The system intent `enhanceDocuments`, which the framework's index knows as `ReaderEnhanceDocumentsIntent`.
    public static var enhanceDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderEnhanceDocumentsIntent")
    }

    /// The system intent `searchDocuments`, which the framework's index knows as `SearchReaderDocumentsIntent`.
    public static var searchDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchReaderDocumentsIntent")
    }

    /// The system intent `openDocument`, which the framework's index knows as `ReaderOpenDocumentsIntent`.
    public static var openDocument: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderOpenDocumentsIntent")
    }

    /// The system intent `rotatePages`, which the framework's index knows as `ReaderRotatePagesIntent`.
    public static var rotatePages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderRotatePagesIntent")
    }

    /// The system intent `deletePages`, which the framework's index knows as `ReaderDeletePagesIntent`.
    public static var deletePages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderDeletePagesIntent")
    }

    /// The system intent `insertPages`, which the framework's index knows as `ReaderInsertPagesIntent`.
    public static var insertPages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderInsertPagesIntent")
    }

}

extension AssistantSchemas.Entity where Self == AssistantSchemas.EntitySchema {
    /// The system entity `reader`, which the framework's index knows as `reader`.
    public static var reader: some AssistantSchemas.ReaderEntity {
        return AssistantSchema.EntitySchema("reader")
    }

    /// The system entity `files`, which the framework's index knows as `files`.
    public static var files: some AssistantSchemas.FilesEntity {
        return AssistantSchema.EntitySchema("files")
    }

    /// The system entity `presentation`, which the framework's index knows as `presentation`.
    public static var presentation: some AssistantSchemas.PresentationEntity {
        return AssistantSchema.EntitySchema("presentation")
    }

    /// The system entity `mail`, which the framework's index knows as `mail`.
    public static var mail: some AssistantSchemas.MailEntity {
        return AssistantSchema.EntitySchema("mail")
    }

    /// The system entity `browser`, which the framework's index knows as `browser`.
    public static var browser: some AssistantSchemas.BrowserEntity {
        return AssistantSchema.EntitySchema("browser")
    }

    /// The system entity `spreadsheet`, which the framework's index knows as `spreadsheet`.
    public static var spreadsheet: some AssistantSchemas.SpreadsheetEntity {
        return AssistantSchema.EntitySchema("spreadsheet")
    }

    /// The system entity `photos`, which the framework's index knows as `photos`.
    public static var photos: some AssistantSchemas.PhotosEntity {
        return AssistantSchema.EntitySchema("photos")
    }

    /// The system entity `books`, which the framework's index knows as `books`.
    public static var books: some AssistantSchemas.BooksEntity {
        return AssistantSchema.EntitySchema("books")
    }

    /// The system entity `wordProcessor`, which the framework's index knows as `wordProcessor`.
    public static var wordProcessor: some AssistantSchemas.WordProcessorEntity {
        return AssistantSchema.EntitySchema("wordProcessor")
    }

    /// The system entity `whiteboard`, which the framework's index knows as `whiteboard`.
    public static var whiteboard: some AssistantSchemas.WhiteboardEntity {
        return AssistantSchema.EntitySchema("whiteboard")
    }

    /// The system entity `journal`, which the framework's index knows as `journal`.
    public static var journal: some AssistantSchemas.JournalEntity {
        return AssistantSchema.EntitySchema("journal")
    }

}

extension AssistantSchemas.ReaderEntity {
    /// The system entity `document`, which the framework's index knows as `ReaderDocumentEntity`.
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("ReaderDocumentEntity")
    }

    /// The system entity `page`, which the framework's index knows as `ReaderPageEntity`.
    public static var page: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("ReaderPageEntity")
    }

}

extension AssistantSchemas.Enum where Self == AssistantSchemas.EnumSchema {
    /// The system enum `reader`, which the framework's index knows as `reader`.
    public static var reader: some AssistantSchemas.ReaderEnum {
        return AssistantSchema.EnumSchema("reader")
    }

    /// The system enum `browser`, which the framework's index knows as `browser`.
    public static var browser: some AssistantSchemas.BrowserEnum {
        return AssistantSchema.EnumSchema("browser")
    }

    /// The system enum `photos`, which the framework's index knows as `photos`.
    public static var photos: some AssistantSchemas.PhotosEnum {
        return AssistantSchema.EnumSchema("photos")
    }

    /// The system enum `books`, which the framework's index knows as `books`.
    public static var books: some AssistantSchemas.BooksEnum {
        return AssistantSchema.EnumSchema("books")
    }

    /// The system enum `camera`, which the framework's index knows as `camera`.
    public static var camera: some AssistantSchemas.CameraEnum {
        return AssistantSchema.EnumSchema("camera")
    }

    /// The system enum `whiteboard`, which the framework's index knows as `whiteboard`.
    public static var whiteboard: some AssistantSchemas.WhiteboardEnum {
        return AssistantSchema.EnumSchema("whiteboard")
    }

}

extension AssistantSchemas.ReaderEnum {
    /// The system enum `documentKind`, which the framework's index knows as `ReaderDocumentKind`.
    public static var documentKind: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("ReaderDocumentKind")
    }

}

extension AssistantSchemas.FilesIntent {
    /// The system intent `createFolder`, which the framework's index knows as `CreateFolderIntent`.
    public static var createFolder: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateFolderIntent")
    }

    /// The system intent `openFile`, which the framework's index knows as `OpenFileIntent`.
    public static var openFile: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenFileIntent")
    }

    /// The system intent `deleteFiles`, which the framework's index knows as `DeleteFilesIntent`.
    public static var deleteFiles: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteFilesIntent")
    }

    /// The system intent `renameFile`, which the framework's index knows as `RenameFileIntent`.
    public static var renameFile: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RenameFileIntent")
    }

    /// The system intent `moveFiles`, which the framework's index knows as `MoveFilesIntent`.
    public static var moveFiles: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("MoveFilesIntent")
    }

}

extension AssistantSchemas.FilesEntity {
    /// The system entity `file`, which the framework's index knows as `FileEntity`.
    public static var file: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("FileEntity")
    }

}

extension AssistantSchemas.PresentationIntent {
    /// The system intent `create`, which the framework's index knows as `CreatePresentationIntent`.
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreatePresentationIntent")
    }

    /// The system intent `open`, which the framework's index knows as `OpenPresentationIntent`.
    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenPresentationIntent")
    }

    /// The system intent `startPlayback`, which the framework's index knows as `StartPlaybackPresentationIntent`.
    public static var startPlayback: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StartPlaybackPresentationIntent")
    }

    /// The system intent `stopPlayback`, which the framework's index knows as `StopPlaybackPresentationIntent`.
    public static var stopPlayback: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StopPlaybackPresentationIntent")
    }

    /// The system intent `update`, which the framework's index knows as `UpdatePresentationIntent`.
    public static var update: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdatePresentationIntent")
    }

    /// The system intent `createSlide`, which the framework's index knows as `CreatePresentationSlideIntent`.
    public static var createSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreatePresentationSlideIntent")
    }

    /// The system intent `openSlide`, which the framework's index knows as `OpenPresentationSlideIntent`.
    public static var openSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenPresentationSlideIntent")
    }

    /// The system intent `setSlideTitle`, which the framework's index knows as `UpdatePresentationSlideIntent`.
    public static var setSlideTitle: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdatePresentationSlideIntent")
    }

    /// The system intent `addTextBoxToSlide`, which the framework's index knows as `AddTextBoxToPresentationSlideIntent`.
    public static var addTextBoxToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextBoxToPresentationSlideIntent")
    }

    /// The system intent `addVideoToSlide`, which the framework's index knows as `AddVideoToPresentationSlideIntent`.
    public static var addVideoToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToPresentationSlideIntent")
    }

    /// The system intent `addImageToSlide`, which the framework's index knows as `AddImageToPresentationSlideIntent`.
    public static var addImageToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToPresentationSlideIntent")
    }

    /// The system intent `addAudioToSlide`, which the framework's index knows as `AddAudioToPresentationSlideIntent`.
    public static var addAudioToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToPresentationSlideIntent")
    }

    /// The system intent `addWebVideoToSlide`, which the framework's index knows as `AddWebVideoToPresentationSlideIntent`.
    public static var addWebVideoToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToPresentationSlideIntent")
    }

    /// The system intent `addCommentToSlide`, which the framework's index knows as `AddCommentToPresentationSlideIntent`.
    public static var addCommentToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddCommentToPresentationSlideIntent")
    }

    /// The system intent `deleteSlide`, which the framework's index knows as `DeletePresentationSlideIntent`.
    public static var deleteSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeletePresentationSlideIntent")
    }

}

extension AssistantSchemas.PresentationEntity {
    /// The system entity `slide`, which the framework's index knows as `PresentationSlideEntity`.
    public static var slide: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationSlideEntity")
    }

    /// The system entity `document`, which the framework's index knows as `PresentationEntity`.
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationEntity")
    }

    /// The system entity `template`, which the framework's index knows as `PresentationTemplateEntity`.
    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationTemplateEntity")
    }

}

extension AssistantSchemas.MailIntent {
    /// The system intent `createDraft`, which the framework's index knows as `CreateDraftIntent`.
    public static var createDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateDraftIntent")
    }

    /// The system intent `updateDraft`, which the framework's index knows as `UpdateDraftIntent`.
    public static var updateDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateDraftIntent")
    }

    /// The system intent `saveDraft`, which the framework's index knows as `SaveDraftIntent`.
    public static var saveDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SaveDraftIntent")
    }

    /// The system intent `deleteDraft`, which the framework's index knows as `DeleteDraftIntent`.
    public static var deleteDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteDraftIntent")
    }

    /// The system intent `sendDraft`, which the framework's index knows as `SendDraftIntent`.
    public static var sendDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SendDraftIntent")
    }

    /// The system intent `forwardMail`, which the framework's index knows as `ForwardMailIntent`.
    public static var forwardMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ForwardMailIntent")
    }

    /// The system intent `replyMail`, which the framework's index knows as `ReplyMailIntent`.
    public static var replyMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReplyMailIntent")
    }

    /// The system intent `archiveMail`, which the framework's index knows as `ArchiveMailIntent`.
    public static var archiveMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ArchiveMailIntent")
    }

    /// The system intent `deleteMail`, which the framework's index knows as `DeleteMailIntent`.
    public static var deleteMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMailIntent")
    }

    /// The system intent `updateMail`, which the framework's index knows as `UpdateMailIntent`.
    public static var updateMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMailIntent")
    }

}

extension AssistantSchemas.MailEntity {
    /// The system entity `account`, which the framework's index knows as `MailAccountEntity`.
    public static var account: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailAccountEntity")
    }

    /// The system entity `mailbox`, which the framework's index knows as `MailboxEntity`.
    public static var mailbox: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailboxEntity")
    }

    /// The system entity `draft`, which the framework's index knows as `MailDraftEntity`.
    public static var draft: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailDraftEntity")
    }

    /// The system entity `message`, which the framework's index knows as `MailMessageEntity`.
    public static var message: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailMessageEntity")
    }

}

extension AssistantSchemas.VisualIntelligenceIntent {
    /// The system intent `semanticContentSearch`, which the framework's index knows as `ShowVisualSearchResultsInAppIntent`.
    public static var semanticContentSearch: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ShowVisualSearchResultsInAppIntent")
    }

}

extension AssistantSchemas.BrowserIntent {
    /// The system intent `bookmarkTab`, which the framework's index knows as `BookmarkTabIntent`.
    public static var bookmarkTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("BookmarkTabIntent")
    }

    /// The system intent `bookmarkURL`, which the framework's index knows as `BookmarkURLIntent`.
    public static var bookmarkURL: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("BookmarkURLIntent")
    }

    /// The system intent `openBookmark`, which the framework's index knows as `OpenBookmarkIntent`.
    public static var openBookmark: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenBookmarkIntent")
    }

    /// The system intent `deleteBookmarks`, which the framework's index knows as `DeleteBookmarksIntent`.
    public static var deleteBookmarks: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteBookmarksIntent")
    }

    /// The system intent `clearHistory`, which the framework's index knows as `ClearHistoryIntent`.
    public static var clearHistory: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ClearHistoryIntent")
    }

    /// The system intent `closeTabs`, which the framework's index knows as `CloseTabsIntent`.
    public static var closeTabs: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CloseTabsIntent")
    }

    /// The system intent `createTab`, which the framework's index knows as `CreateTabIntent`.
    public static var createTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateTabIntent")
    }

    /// The system intent `openURLInTab`, which the framework's index knows as `LoadURLInTabIntent`.
    public static var openURLInTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("LoadURLInTabIntent")
    }

    /// The system intent `switchTab`, which the framework's index knows as `SwitchToTabIntent`.
    public static var switchTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SwitchToTabIntent")
    }

    /// The system intent `createWindow`, which the framework's index knows as `CreateWindowIntent`.
    public static var createWindow: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWindowIntent")
    }

    /// The system intent `closeWindows`, which the framework's index knows as `CloseWindowsIntent`.
    public static var closeWindows: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CloseWindowsIntent")
    }

    /// The system intent `findOnPage`, which the framework's index knows as `FindOnPageIntent`.
    public static var findOnPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("FindOnPageIntent")
    }

    /// The system intent `search`, which the framework's index knows as `SearchWebIntent`.
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchWebIntent")
    }

}

extension AssistantSchemas.BrowserEntity {
    /// The system entity `bookmark`, which the framework's index knows as `BookmarkEntity`.
    public static var bookmark: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookmarkEntity")
    }

    /// The system entity `tab`, which the framework's index knows as `TabEntity`.
    public static var tab: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("TabEntity")
    }

    /// The system entity `window`, which the framework's index knows as `WindowEntity`.
    public static var window: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WindowEntity")
    }

}

extension AssistantSchemas.BrowserEnum {
    /// The system enum `clearHistoryTimeFrame`, which the framework's index knows as `ClearHistoryTimeFrameEnum`.
    public static var clearHistoryTimeFrame: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("ClearHistoryTimeFrameEnum")
    }

}

extension AssistantSchemas.SpreadsheetIntent {
    /// The system intent `create`, which the framework's index knows as `CreateSpreadsheetIntent`.
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateSpreadsheetIntent")
    }

    /// The system intent `open`, which the framework's index knows as `OpenSpreadsheetIntent`.
    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenSpreadsheetIntent")
    }

    /// The system intent `update`, which the framework's index knows as `UpdateSpreadsheetIntent`.
    public static var update: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateSpreadsheetIntent")
    }

    /// The system intent `delete`, which the framework's index knows as `DeleteSpreadsheetIntent`.
    public static var delete: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteSpreadsheetIntent")
    }

    /// The system intent `createSheet`, which the framework's index knows as `CreateSheetIntent`.
    public static var createSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateSheetIntent")
    }

    /// The system intent `openSheet`, which the framework's index knows as `OpenSheetIntent`.
    public static var openSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenSheetIntent")
    }

    /// The system intent `updateSheet`, which the framework's index knows as `UpdateSheetIntent`.
    public static var updateSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateSheetIntent")
    }

    /// The system intent `addImageToSheet`, which the framework's index knows as `AddImageToSheetIntent`.
    public static var addImageToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToSheetIntent")
    }

    /// The system intent `addTextBoxToSheet`, which the framework's index knows as `AddTextboxToSheetIntent`.
    public static var addTextBoxToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextboxToSheetIntent")
    }

    /// The system intent `addVideoToSheet`, which the framework's index knows as `AddVideoToSheetIntent`.
    public static var addVideoToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToSheetIntent")
    }

    /// The system intent `addAudioToSheet`, which the framework's index knows as `AddAudioToSheetIntent`.
    public static var addAudioToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToSheetIntent")
    }

    /// The system intent `addWebVideoToSheet`, which the framework's index knows as `AddWebVideoToSheetIntent`.
    public static var addWebVideoToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToSheetIntent")
    }

    /// The system intent `addCommentToSheet`, which the framework's index knows as `AddCommentToSheetIntent`.
    public static var addCommentToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddCommentToSheetIntent")
    }

    /// The system intent `deleteSheet`, which the framework's index knows as `DeleteSheetIntent`.
    public static var deleteSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteSheetIntent")
    }

}

extension AssistantSchemas.SpreadsheetEntity {
    /// The system entity `sheet`, which the framework's index knows as `SheetEntity`.
    public static var sheet: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SheetEntity")
    }

    /// The system entity `document`, which the framework's index knows as `SpreadsheetEntity`.
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SpreadsheetEntity")
    }

    /// The system entity `template`, which the framework's index knows as `SpreadsheetTemplateEntity`.
    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SpreadsheetTemplateEntity")
    }

}

extension AssistantSchemas.PhotosIntent {
    /// The system intent `createAlbum`, which the framework's index knows as `CreateMediaAlbumIntent`.
    public static var createAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateMediaAlbumIntent")
    }

    /// The system intent `openAlbum`, which the framework's index knows as `OpenMediaAlbumIntent`.
    public static var openAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenMediaAlbumIntent")
    }

    /// The system intent `updateAlbum`, which the framework's index knows as `UpdateMediaAlbumIntent`.
    public static var updateAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaAlbumIntent")
    }

    /// The system intent `deleteAlbum`, which the framework's index knows as `DeleteMediaAlbumIntent`.
    public static var deleteAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMediaAlbumIntent")
    }

    /// The system intent `createAssets`, which the framework's index knows as `CreateMediaAssetsIntent`.
    public static var createAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateMediaAssetsIntent")
    }

    /// The system intent `openAsset`, which the framework's index knows as `OpenMediaAssetIntent`.
    public static var openAsset: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenMediaAssetIntent")
    }

    /// The system intent `updateAsset`, which the framework's index knows as `UpdateMediaAssetIntent`.
    public static var updateAsset: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaAssetIntent")
    }

    /// The system intent `deleteAssets`, which the framework's index knows as `DeleteMediaAssetsIntent`.
    public static var deleteAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMediaAssetsIntent")
    }

    /// The system intent `duplicateAssets`, which the framework's index knows as `DuplicateMediaAssetsIntent`.
    public static var duplicateAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DuplicateMediaAssetsIntent")
    }

    /// The system intent `postToSharedAlbum`, which the framework's index knows as `PostToSharedAlbumIntent`.
    public static var postToSharedAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PostToSharedAlbumIntent")
    }

    /// The system intent `addAssetsToAlbum`, which the framework's index knows as `AddMediaAssetsToAlbumIntent`.
    public static var addAssetsToAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddMediaAssetsToAlbumIntent")
    }

    /// The system intent `removeAssetsFromAlbum`, which the framework's index knows as `RemoveMediaAssetsFromAlbumIntent`.
    public static var removeAssetsFromAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RemoveMediaAssetsFromAlbumIntent")
    }

    /// The system intent `search`, which the framework's index knows as `SearchMediaIntent`.
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchMediaIntent")
    }

    /// The system intent `updateRecognizedPerson`, which the framework's index knows as `UpdateMediaPersonIntent`.
    public static var updateRecognizedPerson: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaPersonIntent")
    }

    /// The system intent `copyEdits`, which the framework's index knows as `CopyMediaEditsIntent`.
    public static var copyEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CopyMediaEditsIntent")
    }

    /// The system intent `pasteEdits`, which the framework's index knows as `PasteMediaEditsIntent`.
    public static var pasteEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PasteMediaEditsIntent")
    }

    /// The system intent `cleanupPhoto`, which the framework's index knows as `CleanupMediaIntent`.
    public static var cleanupPhoto: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CleanupMediaIntent")
    }

    /// The system intent `setExposure`, which the framework's index knows as `SetMediaExposureIntent`.
    public static var setExposure: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaExposureIntent")
    }

    /// The system intent `setSaturation`, which the framework's index knows as `SetMediaSaturationIntent`.
    public static var setSaturation: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaSaturationIntent")
    }

    /// The system intent `setWarmth`, which the framework's index knows as `SetMediaWarmthIntent`.
    public static var setWarmth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaWarmthIntent")
    }

    /// The system intent `toggleSuggestedEdits`, which the framework's index knows as `EnhanceMediaIntent`.
    public static var toggleSuggestedEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("EnhanceMediaIntent")
    }

    /// The system intent `setFilter`, which the framework's index knows as `ApplyMediaFilterIntent`.
    public static var setFilter: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ApplyMediaFilterIntent")
    }

    /// The system intent `setDepth`, which the framework's index knows as `SetMediaApertureIntent`.
    public static var setDepth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaApertureIntent")
    }

    /// The system intent `toggleDepth`, which the framework's index knows as `SetMediaDepthIntent`.
    public static var toggleDepth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaDepthIntent")
    }

    /// The system intent `crop`, which the framework's index knows as `CropMediaIntent`.
    public static var crop: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CropMediaIntent")
    }

    /// The system intent `straighten`, which the framework's index knows as `StraightenMediaIntent`.
    public static var straighten: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StraightenMediaIntent")
    }

    /// The system intent `setRotation`, which the framework's index knows as `RotateMediaIntent`.
    public static var setRotation: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RotateMediaIntent")
    }

}

extension AssistantSchemas.PhotosEntity {
    /// The system entity `asset`, which the framework's index knows as `PhotoEntity`.
    public static var asset: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoEntity")
    }

    /// The system entity `album`, which the framework's index knows as `PhotoAlbumEntity`.
    public static var album: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoAlbumEntity")
    }

    /// The system entity `recognizedPerson`, which the framework's index knows as `PhotoPersonEntity`.
    public static var recognizedPerson: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoPersonEntity")
    }

}

extension AssistantSchemas.PhotosEnum {
    /// The system enum `assetType`, which the framework's index knows as `PhotoAssetType`.
    public static var assetType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoAssetType")
    }

    /// The system enum `albumType`, which the framework's index knows as `PhotoAlbumType`.
    public static var albumType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoAlbumType")
    }

    /// The system enum `filterType`, which the framework's index knows as `PhotoFilterEffectType`.
    public static var filterType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoFilterEffectType")
    }

    /// The system enum `rotationDirection`, which the framework's index knows as `PhotoRotationDirection`.
    public static var rotationDirection: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoRotationDirection")
    }

}

extension AssistantSchemas.BooksIntent {
    /// The system intent `openBook`, which the framework's index knows as `OpenBookIntent`.
    public static var openBook: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenBookIntent")
    }

    /// The system intent `playAudiobook`, which the framework's index knows as `PlayAudiobookIntent`.
    public static var playAudiobook: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PlayAudiobookIntent")
    }

    /// The system intent `navigatePage`, which the framework's index knows as `NavigateBookPageIntent`.
    public static var navigatePage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("NavigateBookPageIntent")
    }

    /// The system intent `updateFontSize`, which the framework's index knows as `UpdateBookFontSizeIntent`.
    public static var updateFontSize: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookFontSizeIntent")
    }

    /// The system intent `updateLineSpacing`, which the framework's index knows as `UpdateBookLineSpacingIntent`.
    public static var updateLineSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookLineSpacingIntent")
    }

    /// The system intent `updateCharacterSpacing`, which the framework's index knows as `UpdateCharacterSpacingIntent`.
    public static var updateCharacterSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCharacterSpacingIntent")
    }

    /// The system intent `updateWordSpacing`, which the framework's index knows as `UpdateWordSpacingIntent`.
    public static var updateWordSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateWordSpacingIntent")
    }

    /// The system intent `updateSettings`, which the framework's index knows as `UpdateBookSettingsIntent`.
    public static var updateSettings: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookSettingsIntent")
    }

    /// The system intent `search`, which the framework's index knows as `SearchLibraryIntent`.
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchLibraryIntent")
    }

}

extension AssistantSchemas.BooksEntity {
    /// The system entity `book`, which the framework's index knows as `BookEntity`.
    public static var book: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookEntity")
    }

    /// The system entity `audiobook`, which the framework's index knows as `AudiobookEntity`.
    public static var audiobook: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("AudiobookEntity")
    }

    /// The system entity `settings`, which the framework's index knows as `BookSettingsEntity`.
    public static var settings: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookSettingsEntity")
    }

}

extension AssistantSchemas.BooksEnum {
    /// The system enum `contentType`, which the framework's index knows as `BookContentType`.
    public static var contentType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookContentType")
    }

    /// The system enum `font`, which the framework's index knows as `BookFont`.
    public static var font: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookFont")
    }

    /// The system enum `fontSize`, which the framework's index knows as `BookFontSize`.
    public static var fontSize: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookFontSize")
    }

    /// The system enum `navigationDirection`, which the framework's index knows as `BookNavigationDirection`.
    public static var navigationDirection: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookNavigationDirection")
    }

    /// The system enum `relativeFontChange`, which the framework's index knows as `BookRelativeFontChange`.
    public static var relativeFontChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeFontChange")
    }

    /// The system enum `relativeCharacterSpacingChange`, which the framework's index knows as `BookRelativeCharacterSpacingChange`.
    public static var relativeCharacterSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeCharacterSpacingChange")
    }

    /// The system enum `relativeLineSpacingChange`, which the framework's index knows as `BookRelativeLineSpacingChange`.
    public static var relativeLineSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeLineSpacingChange")
    }

    /// The system enum `relativeWordSpacingChange`, which the framework's index knows as `BookRelativeWordSpacingChange`.
    public static var relativeWordSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeWordSpacingChange")
    }

    /// The system enum `theme`, which the framework's index knows as `BookTheme`.
    public static var theme: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookTheme")
    }

    /// The system enum `pageNavigationSetting`, which the framework's index knows as `BookPageNavigationSetting`.
    public static var pageNavigationSetting: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookPageNavigationSetting")
    }

}

extension AssistantSchemas.CameraIntent {
    /// The system intent `openInCaptureMode`, which the framework's index knows as `NavigateToCaptureModeIntent`.
    public static var openInCaptureMode: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("NavigateToCaptureModeIntent")
    }

    /// The system intent `switchDevice`, which the framework's index knows as `FlipCameraIntent`.
    public static var switchDevice: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("FlipCameraIntent")
    }

    /// The system intent `setDevice`, which the framework's index knows as `SetActiveDeviceIntent`.
    public static var setDevice: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetActiveDeviceIntent")
    }

    /// The system intent `startCapture`, which the framework's index knows as `StartCameraCaptureIntent`.
    public static var startCapture: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StartCameraCaptureIntent")
    }

    /// The system intent `stopCapture`, which the framework's index knows as `StopCaptureIntent`.
    public static var stopCapture: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StopCaptureIntent")
    }

}

extension AssistantSchemas.CameraEnum {
    /// The system enum `captureMode`, which the framework's index knows as `CaptureMode`.
    public static var captureMode: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureMode")
    }

    /// The system enum `captureDuration`, which the framework's index knows as `CaptureDuration`.
    public static var captureDuration: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureDuration")
    }

    /// The system enum `captureDevice`, which the framework's index knows as `CaptureDevice`.
    public static var captureDevice: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureDevice")
    }

}

extension AssistantSchemas.AssistantIntent {
    /// The system intent `activate`, which the framework's index knows as `ActivateAssistantIntent`.
    public static var activate: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ActivateAssistantIntent")
    }

}

extension AssistantSchemas.SystemIntent {
    /// The system intent `search`, which the framework's index knows as `ShowInAppSearchResultsIntent`.
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ShowInAppSearchResultsIntent")
    }

}

extension AssistantSchemas.WordProcessorIntent {
    /// The system intent `create`, which the framework's index knows as `CreateWordProcessorDocumentIntent`.
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWordProcessorDocumentIntent")
    }

    /// The system intent `open`, which the framework's index knows as `OpenWordProcessorDocumentIntent`.
    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenWordProcessorDocumentIntent")
    }

    /// The system intent `createPage`, which the framework's index knows as `CreateWordProcessorPageIntent`.
    public static var createPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWordProcessorPageIntent")
    }

    /// The system intent `openPage`, which the framework's index knows as `OpenWordProcessorPageIntent`.
    public static var openPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenWordProcessorPageIntent")
    }

    /// The system intent `addTextBoxToPage`, which the framework's index knows as `AddTextBoxToWordProcessorPageIntent`.
    public static var addTextBoxToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextBoxToWordProcessorPageIntent")
    }

    /// The system intent `addVideoToPage`, which the framework's index knows as `AddVideoToWordProcessorPageIntent`.
    public static var addVideoToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToWordProcessorPageIntent")
    }

    /// The system intent `addImageToPage`, which the framework's index knows as `AddImageToWordProcessorPageIntent`.
    public static var addImageToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToWordProcessorPageIntent")
    }

    /// The system intent `addAudioToPage`, which the framework's index knows as `AddAudioToWordProcessorPageIntent`.
    public static var addAudioToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToWordProcessorPageIntent")
    }

    /// The system intent `addWebVideoToPage`, which the framework's index knows as `AddWebVideoToWordProcessorPageIntent`.
    public static var addWebVideoToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToWordProcessorPageIntent")
    }

}

extension AssistantSchemas.WordProcessorEntity {
    /// The system entity `document`, which the framework's index knows as `WordProcessorDocumentEntity`.
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorDocumentEntity")
    }

    /// The system entity `page`, which the framework's index knows as `WordProcessorPageEntity`.
    public static var page: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorPageEntity")
    }

    /// The system entity `template`, which the framework's index knows as `WordProcessorDocumentTemplateEntity`.
    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorDocumentTemplateEntity")
    }

}

extension AssistantSchemas.WhiteboardIntent {
    /// The system intent `createBoard`, which the framework's index knows as `CreateCanvasBoardIntent`.
    public static var createBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateCanvasBoardIntent")
    }

    /// The system intent `openBoard`, which the framework's index knows as `OpenCanvasBoardIntent`.
    public static var openBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenCanvasBoardIntent")
    }

    /// The system intent `updateBoard`, which the framework's index knows as `UpdateCanvasBoardIntent`.
    public static var updateBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCanvasBoardIntent")
    }

    /// The system intent `deleteBoard`, which the framework's index knows as `DeleteCanvasBoardIntent`.
    public static var deleteBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteCanvasBoardIntent")
    }

    /// The system intent `createItem`, which the framework's index knows as `CreateCanvasItemIntent`.
    public static var createItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateCanvasItemIntent")
    }

    /// The system intent `updateItem`, which the framework's index knows as `UpdateCanvasItemIntent`.
    public static var updateItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCanvasItemIntent")
    }

    /// The system intent `deleteItem`, which the framework's index knows as `DeleteCanvasItemIntent`.
    public static var deleteItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteCanvasItemIntent")
    }

}

extension AssistantSchemas.WhiteboardEntity {
    /// The system entity `board`, which the framework's index knows as `CanvasEntity`.
    public static var board: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("CanvasEntity")
    }

    /// The system entity `item`, which the framework's index knows as `CanvasItemEntity`.
    public static var item: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("CanvasItemEntity")
    }

}

extension AssistantSchemas.WhiteboardEnum {
    /// The system enum `color`, which the framework's index knows as `CanvasColor`.
    public static var color: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CanvasColor")
    }

    /// The system enum `itemType`, which the framework's index knows as `CanvasItemType`.
    public static var itemType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CanvasItemType")
    }

}

extension AssistantSchemas.JournalIntent {
    /// The system intent `createEntry`, which the framework's index knows as `CreateJournalEntryIntent`.
    public static var createEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateJournalEntryIntent")
    }

    /// The system intent `createAudioEntry`, which the framework's index knows as `CreateJournalAudioEntryIntent`.
    public static var createAudioEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateJournalAudioEntryIntent")
    }

    /// The system intent `search`, which the framework's index knows as `SearchJournalEntriesIntent`.
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchJournalEntriesIntent")
    }

    /// The system intent `updateEntry`, which the framework's index knows as `UpdateJournalEntryIntent`.
    public static var updateEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateJournalEntryIntent")
    }

    /// The system intent `deleteEntry`, which the framework's index knows as `DeleteJournalEntryIntent`.
    public static var deleteEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteJournalEntryIntent")
    }

}

extension AssistantSchemas.JournalEntity {
    /// The system entity `entry`, which the framework's index knows as `JournalEntity`.
    public static var entry: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("JournalEntity")
    }

}

