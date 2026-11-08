import UIKit
import UniformTypeIdentifiers

public func openingPicker(_ types: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
    return UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: asCopy)
}

public func openingPicker(_ types: [UTType]) -> UIDocumentPickerViewController {
    return UIDocumentPickerViewController(forOpeningContentTypes: types)
}

public func pickerForIdentifiers(_ identifiers: [String], asCopy: Bool) -> UIDocumentPickerViewController {
    let types = identifiers.map { UTType($0) ?? UTType(importedAs: $0) }
    return UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: asCopy)
}

public func browser(_ types: [UTType]) -> UIDocumentBrowserViewController {
    return UIDocumentBrowserViewController(forOpening: types)
}

public func recentTypes(_ browser: UIDocumentBrowserViewController) -> [UTType] {
    return browser.contentTypesForRecentDocuments
}
