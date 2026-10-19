import Foundation

public protocol RevenantNamedSchema {
    var identifier: String { get }
}

public struct AssistantSchema: Sendable {
    public let identifier: String

    public init(_ schema: String) {
        self.identifier = schema
    }

    public typealias IntentSchema = AssistantSchemas.IntentSchema

    public typealias EntitySchema = AssistantSchemas.EntitySchema

    public typealias EnumSchema = AssistantSchemas.EnumSchema
}

extension AssistantSchemas {
    public struct IntentSchema: RevenantNamedSchema {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
    public struct EntitySchema: RevenantNamedSchema {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
    public struct EnumSchema: RevenantNamedSchema {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }
    }
}

public enum AssistantSchemas {
    @_marker public protocol Model {}

    @_marker public protocol Intent: Model {}

    @_marker public protocol Entity: Model {}

    @_marker public protocol Enum: Model {}

    @_marker public protocol ReaderIntent: Intent {}
    @_marker public protocol FilesIntent: Intent {}
    @_marker public protocol PresentationIntent: Intent {}
    @_marker public protocol MailIntent: Intent {}
    @_marker public protocol VisualIntelligenceIntent: Intent {}
    @_marker public protocol BrowserIntent: Intent {}
    @_marker public protocol SpreadsheetIntent: Intent {}
    @_marker public protocol PhotosIntent: Intent {}
    @_marker public protocol BooksIntent: Intent {}
    @_marker public protocol CameraIntent: Intent {}
    @_marker public protocol AssistantIntent: Intent {}
    @_marker public protocol SystemIntent: Intent {}
    @_marker public protocol WordProcessorIntent: Intent {}
    @_marker public protocol WhiteboardIntent: Intent {}
    @_marker public protocol JournalIntent: Intent {}
    @_marker public protocol ReaderEntity: Entity {}
    @_marker public protocol FilesEntity: Entity {}
    @_marker public protocol PresentationEntity: Entity {}
    @_marker public protocol MailEntity: Entity {}
    @_marker public protocol BrowserEntity: Entity {}
    @_marker public protocol SpreadsheetEntity: Entity {}
    @_marker public protocol PhotosEntity: Entity {}
    @_marker public protocol BooksEntity: Entity {}
    @_marker public protocol WordProcessorEntity: Entity {}
    @_marker public protocol WhiteboardEntity: Entity {}
    @_marker public protocol JournalEntity: Entity {}
    @_marker public protocol ReaderEnum: Enum {}
    @_marker public protocol BrowserEnum: Enum {}
    @_marker public protocol PhotosEnum: Enum {}
    @_marker public protocol BooksEnum: Enum {}
    @_marker public protocol _AppShortcutsContentMarker: Enum {}
    @_marker public protocol _AppShortcutsContentEmitterMarker: Enum {}
    @_marker public protocol _LimitedAvailabilityAppShortcutsContentMarker: Enum {}
    @_marker public protocol CameraEnum: Enum {}
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
    public static var reader: some AssistantSchemas.ReaderIntent {
        return AssistantSchema.IntentSchema("reader")
    }

    public static var files: some AssistantSchemas.FilesIntent {
        return AssistantSchema.IntentSchema("files")
    }

    public static var presentation: some AssistantSchemas.PresentationIntent {
        return AssistantSchema.IntentSchema("com.apple.Presentation")
    }

    public static var mail: some AssistantSchemas.MailIntent {
        return AssistantSchema.IntentSchema("mail")
    }

    public static var visualIntelligence: some AssistantSchemas.VisualIntelligenceIntent {
        return AssistantSchema.IntentSchema("visualIntelligence")
    }

    public static var browser: some AssistantSchemas.BrowserIntent {
        return AssistantSchema.IntentSchema("Intent")
    }

    public static var spreadsheet: some AssistantSchemas.SpreadsheetIntent {
        return AssistantSchema.IntentSchema("spreadsheet")
    }

    public static var photos: some AssistantSchemas.PhotosIntent {
        return AssistantSchema.IntentSchema("photos")
    }

    public static var books: some AssistantSchemas.BooksIntent {
        return AssistantSchema.IntentSchema("books")
    }

    public static var camera: some AssistantSchemas.CameraIntent {
        return AssistantSchema.IntentSchema("camera")
    }

    public static var assistant: some AssistantSchemas.AssistantIntent {
        return AssistantSchema.IntentSchema("assistant")
    }

    public static var system: some AssistantSchemas.SystemIntent {
        return AssistantSchema.IntentSchema("system")
    }

    public static var wordProcessor: some AssistantSchemas.WordProcessorIntent {
        return AssistantSchema.IntentSchema("wordProcessor")
    }

    public static var whiteboard: some AssistantSchemas.WhiteboardIntent {
        return AssistantSchema.IntentSchema("whiteboard")
    }

    public static var journal: some AssistantSchemas.JournalIntent {
        return AssistantSchema.IntentSchema("journal")
    }

}

extension AssistantSchemas.ReaderIntent {
    public static var rotateDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderRotateDocumentsIntent")
    }

    public static var resizeDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderResizeDocumentsIntent")
    }

    public static var openPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderOpenPageIntent")
    }

    public static var enhanceDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderEnhanceDocumentsIntent")
    }

    public static var searchDocuments: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchReaderDocumentsIntent")
    }

    public static var openDocument: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderOpenDocumentsIntent")
    }

    public static var rotatePages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderRotatePagesIntent")
    }

    public static var deletePages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderDeletePagesIntent")
    }

    public static var insertPages: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReaderInsertPagesIntent")
    }

}

extension AssistantSchemas.Entity where Self == AssistantSchemas.EntitySchema {
    public static var reader: some AssistantSchemas.ReaderEntity {
        return AssistantSchema.EntitySchema("reader")
    }

    public static var files: some AssistantSchemas.FilesEntity {
        return AssistantSchema.EntitySchema("files")
    }

    public static var presentation: some AssistantSchemas.PresentationEntity {
        return AssistantSchema.EntitySchema("presentation")
    }

    public static var mail: some AssistantSchemas.MailEntity {
        return AssistantSchema.EntitySchema("mail")
    }

    public static var browser: some AssistantSchemas.BrowserEntity {
        return AssistantSchema.EntitySchema("browser")
    }

    public static var spreadsheet: some AssistantSchemas.SpreadsheetEntity {
        return AssistantSchema.EntitySchema("spreadsheet")
    }

    public static var photos: some AssistantSchemas.PhotosEntity {
        return AssistantSchema.EntitySchema("photos")
    }

    public static var books: some AssistantSchemas.BooksEntity {
        return AssistantSchema.EntitySchema("books")
    }

    public static var wordProcessor: some AssistantSchemas.WordProcessorEntity {
        return AssistantSchema.EntitySchema("wordProcessor")
    }

    public static var whiteboard: some AssistantSchemas.WhiteboardEntity {
        return AssistantSchema.EntitySchema("whiteboard")
    }

    public static var journal: some AssistantSchemas.JournalEntity {
        return AssistantSchema.EntitySchema("journal")
    }

}

extension AssistantSchemas.ReaderEntity {
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("ReaderDocumentEntity")
    }

    public static var page: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("ReaderPageEntity")
    }

}

extension AssistantSchemas.Enum where Self == AssistantSchemas.EnumSchema {
    public static var reader: some AssistantSchemas.ReaderEnum {
        return AssistantSchema.EnumSchema("reader")
    }

    public static var browser: some AssistantSchemas.BrowserEnum {
        return AssistantSchema.EnumSchema("browser")
    }

    public static var photos: some AssistantSchemas.PhotosEnum {
        return AssistantSchema.EnumSchema("photos")
    }

    public static var books: some AssistantSchemas.BooksEnum {
        return AssistantSchema.EnumSchema("books")
    }

    public static var camera: some AssistantSchemas.CameraEnum {
        return AssistantSchema.EnumSchema("camera")
    }

    public static var whiteboard: some AssistantSchemas.WhiteboardEnum {
        return AssistantSchema.EnumSchema("whiteboard")
    }

}

extension AssistantSchemas.ReaderEnum {
    public static var documentKind: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("ReaderDocumentKind")
    }

}

extension AssistantSchemas.FilesIntent {
    public static var createFolder: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateFolderIntent")
    }

    public static var openFile: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenFileIntent")
    }

    public static var deleteFiles: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteFilesIntent")
    }

    public static var renameFile: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RenameFileIntent")
    }

    public static var moveFiles: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("MoveFilesIntent")
    }

}

extension AssistantSchemas.FilesEntity {
    public static var file: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("FileEntity")
    }

}

extension AssistantSchemas.PresentationIntent {
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreatePresentationIntent")
    }

    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenPresentationIntent")
    }

    public static var startPlayback: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StartPlaybackPresentationIntent")
    }

    public static var stopPlayback: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StopPlaybackPresentationIntent")
    }

    public static var update: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdatePresentationIntent")
    }

    public static var createSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreatePresentationSlideIntent")
    }

    public static var openSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenPresentationSlideIntent")
    }

    public static var setSlideTitle: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdatePresentationSlideIntent")
    }

    public static var addTextBoxToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextBoxToPresentationSlideIntent")
    }

    public static var addVideoToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToPresentationSlideIntent")
    }

    public static var addImageToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToPresentationSlideIntent")
    }

    public static var addAudioToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToPresentationSlideIntent")
    }

    public static var addWebVideoToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToPresentationSlideIntent")
    }

    public static var addCommentToSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddCommentToPresentationSlideIntent")
    }

    public static var deleteSlide: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeletePresentationSlideIntent")
    }

}

extension AssistantSchemas.PresentationEntity {
    public static var slide: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationSlideEntity")
    }

    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationEntity")
    }

    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PresentationTemplateEntity")
    }

}

extension AssistantSchemas.MailIntent {
    public static var createDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateDraftIntent")
    }

    public static var updateDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateDraftIntent")
    }

    public static var saveDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SaveDraftIntent")
    }

    public static var deleteDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteDraftIntent")
    }

    public static var sendDraft: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SendDraftIntent")
    }

    public static var forwardMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ForwardMailIntent")
    }

    public static var replyMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ReplyMailIntent")
    }

    public static var archiveMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ArchiveMailIntent")
    }

    public static var deleteMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMailIntent")
    }

    public static var updateMail: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMailIntent")
    }

}

extension AssistantSchemas.MailEntity {
    public static var account: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailAccountEntity")
    }

    public static var mailbox: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailboxEntity")
    }

    public static var draft: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailDraftEntity")
    }

    public static var message: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("MailMessageEntity")
    }

}

extension AssistantSchemas.VisualIntelligenceIntent {
    public static var semanticContentSearch: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ShowVisualSearchResultsInAppIntent")
    }

}

extension AssistantSchemas.BrowserIntent {
    public static var bookmarkTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("BookmarkTabIntent")
    }

    public static var bookmarkURL: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("BookmarkURLIntent")
    }

    public static var openBookmark: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenBookmarkIntent")
    }

    public static var deleteBookmarks: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteBookmarksIntent")
    }

    public static var clearHistory: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ClearHistoryIntent")
    }

    public static var closeTabs: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CloseTabsIntent")
    }

    public static var createTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateTabIntent")
    }

    public static var openURLInTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("LoadURLInTabIntent")
    }

    public static var switchTab: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SwitchToTabIntent")
    }

    public static var createWindow: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWindowIntent")
    }

    public static var closeWindows: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CloseWindowsIntent")
    }

    public static var findOnPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("FindOnPageIntent")
    }

    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchWebIntent")
    }

}

extension AssistantSchemas.BrowserEntity {
    public static var bookmark: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookmarkEntity")
    }

    public static var tab: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("TabEntity")
    }

    public static var window: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WindowEntity")
    }

}

extension AssistantSchemas.BrowserEnum {
    public static var clearHistoryTimeFrame: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("ClearHistoryTimeFrameEnum")
    }

}

extension AssistantSchemas.SpreadsheetIntent {
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateSpreadsheetIntent")
    }

    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenSpreadsheetIntent")
    }

    public static var update: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateSpreadsheetIntent")
    }

    public static var delete: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteSpreadsheetIntent")
    }

    public static var createSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateSheetIntent")
    }

    public static var openSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenSheetIntent")
    }

    public static var updateSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateSheetIntent")
    }

    public static var addImageToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToSheetIntent")
    }

    public static var addTextBoxToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextboxToSheetIntent")
    }

    public static var addVideoToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToSheetIntent")
    }

    public static var addAudioToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToSheetIntent")
    }

    public static var addWebVideoToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToSheetIntent")
    }

    public static var addCommentToSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddCommentToSheetIntent")
    }

    public static var deleteSheet: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteSheetIntent")
    }

}

extension AssistantSchemas.SpreadsheetEntity {
    public static var sheet: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SheetEntity")
    }

    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SpreadsheetEntity")
    }

    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("SpreadsheetTemplateEntity")
    }

}

extension AssistantSchemas.PhotosIntent {
    public static var createAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateMediaAlbumIntent")
    }

    public static var openAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenMediaAlbumIntent")
    }

    public static var updateAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaAlbumIntent")
    }

    public static var deleteAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMediaAlbumIntent")
    }

    public static var createAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateMediaAssetsIntent")
    }

    public static var openAsset: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenMediaAssetIntent")
    }

    public static var updateAsset: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaAssetIntent")
    }

    public static var deleteAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteMediaAssetsIntent")
    }

    public static var duplicateAssets: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DuplicateMediaAssetsIntent")
    }

    public static var postToSharedAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PostToSharedAlbumIntent")
    }

    public static var addAssetsToAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddMediaAssetsToAlbumIntent")
    }

    public static var removeAssetsFromAlbum: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RemoveMediaAssetsFromAlbumIntent")
    }

    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchMediaIntent")
    }

    public static var updateRecognizedPerson: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateMediaPersonIntent")
    }

    public static var copyEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CopyMediaEditsIntent")
    }

    public static var pasteEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PasteMediaEditsIntent")
    }

    public static var cleanupPhoto: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CleanupMediaIntent")
    }

    public static var setExposure: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaExposureIntent")
    }

    public static var setSaturation: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaSaturationIntent")
    }

    public static var setWarmth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaWarmthIntent")
    }

    public static var toggleSuggestedEdits: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("EnhanceMediaIntent")
    }

    public static var setFilter: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ApplyMediaFilterIntent")
    }

    public static var setDepth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaApertureIntent")
    }

    public static var toggleDepth: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetMediaDepthIntent")
    }

    public static var crop: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CropMediaIntent")
    }

    public static var straighten: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StraightenMediaIntent")
    }

    public static var setRotation: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("RotateMediaIntent")
    }

}

extension AssistantSchemas.PhotosEntity {
    public static var asset: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoEntity")
    }

    public static var album: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoAlbumEntity")
    }

    public static var recognizedPerson: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("PhotoPersonEntity")
    }

}

extension AssistantSchemas.PhotosEnum {
    public static var assetType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoAssetType")
    }

    public static var albumType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoAlbumType")
    }

    public static var filterType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoFilterEffectType")
    }

    public static var rotationDirection: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("PhotoRotationDirection")
    }

}

extension AssistantSchemas.BooksIntent {
    public static var openBook: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenBookIntent")
    }

    public static var playAudiobook: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("PlayAudiobookIntent")
    }

    public static var navigatePage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("NavigateBookPageIntent")
    }

    public static var updateFontSize: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookFontSizeIntent")
    }

    public static var updateLineSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookLineSpacingIntent")
    }

    public static var updateCharacterSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCharacterSpacingIntent")
    }

    public static var updateWordSpacing: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateWordSpacingIntent")
    }

    public static var updateSettings: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateBookSettingsIntent")
    }

    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchLibraryIntent")
    }

}

extension AssistantSchemas.BooksEntity {
    public static var book: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookEntity")
    }

    public static var audiobook: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("AudiobookEntity")
    }

    public static var settings: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("BookSettingsEntity")
    }

}

extension AssistantSchemas.BooksEnum {
    public static var contentType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookContentType")
    }

    public static var font: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookFont")
    }

    public static var fontSize: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookFontSize")
    }

    public static var navigationDirection: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookNavigationDirection")
    }

    public static var relativeFontChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeFontChange")
    }

    public static var relativeCharacterSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeCharacterSpacingChange")
    }

    public static var relativeLineSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeLineSpacingChange")
    }

    public static var relativeWordSpacingChange: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookRelativeWordSpacingChange")
    }

    public static var theme: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookTheme")
    }

    public static var pageNavigationSetting: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("BookPageNavigationSetting")
    }

}

extension AssistantSchemas.CameraIntent {
    public static var openInCaptureMode: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("NavigateToCaptureModeIntent")
    }

    public static var switchDevice: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("FlipCameraIntent")
    }

    public static var setDevice: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SetActiveDeviceIntent")
    }

    public static var startCapture: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StartCameraCaptureIntent")
    }

    public static var stopCapture: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("StopCaptureIntent")
    }

}

extension AssistantSchemas.CameraEnum {
    public static var captureMode: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureMode")
    }

    public static var captureDuration: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureDuration")
    }

    public static var captureDevice: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CaptureDevice")
    }

}

extension AssistantSchemas.AssistantIntent {
    public static var activate: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ActivateAssistantIntent")
    }

}

extension AssistantSchemas.SystemIntent {
    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("ShowInAppSearchResultsIntent")
    }

}

extension AssistantSchemas.WordProcessorIntent {
    public static var create: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWordProcessorDocumentIntent")
    }

    public static var open: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenWordProcessorDocumentIntent")
    }

    public static var createPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateWordProcessorPageIntent")
    }

    public static var openPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenWordProcessorPageIntent")
    }

    public static var addTextBoxToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddTextBoxToWordProcessorPageIntent")
    }

    public static var addVideoToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddVideoToWordProcessorPageIntent")
    }

    public static var addImageToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddImageToWordProcessorPageIntent")
    }

    public static var addAudioToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddAudioToWordProcessorPageIntent")
    }

    public static var addWebVideoToPage: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("AddWebVideoToWordProcessorPageIntent")
    }

}

extension AssistantSchemas.WordProcessorEntity {
    public static var document: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorDocumentEntity")
    }

    public static var page: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorPageEntity")
    }

    public static var template: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("WordProcessorDocumentTemplateEntity")
    }

}

extension AssistantSchemas.WhiteboardIntent {
    public static var createBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateCanvasBoardIntent")
    }

    public static var openBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("OpenCanvasBoardIntent")
    }

    public static var updateBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCanvasBoardIntent")
    }

    public static var deleteBoard: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteCanvasBoardIntent")
    }

    public static var createItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateCanvasItemIntent")
    }

    public static var updateItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateCanvasItemIntent")
    }

    public static var deleteItem: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteCanvasItemIntent")
    }

}

extension AssistantSchemas.WhiteboardEntity {
    public static var board: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("CanvasEntity")
    }

    public static var item: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("CanvasItemEntity")
    }

}

extension AssistantSchemas.WhiteboardEnum {
    public static var color: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CanvasColor")
    }

    public static var itemType: some AssistantSchemas.Enum {
        return AssistantSchema.EnumSchema("CanvasItemType")
    }

}

extension AssistantSchemas.JournalIntent {
    public static var createEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateJournalEntryIntent")
    }

    public static var createAudioEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("CreateJournalAudioEntryIntent")
    }

    public static var search: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("SearchJournalEntriesIntent")
    }

    public static var updateEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("UpdateJournalEntryIntent")
    }

    public static var deleteEntry: some AssistantSchemas.Intent {
        return AssistantSchema.IntentSchema("DeleteJournalEntryIntent")
    }

}

extension AssistantSchemas.JournalEntity {
    public static var entry: some AssistantSchemas.Entity {
        return AssistantSchema.EntitySchema("JournalEntity")
    }

}
