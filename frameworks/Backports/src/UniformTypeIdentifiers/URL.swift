import Foundation

extension URL {
    public func appendingPathComponent(_ partialName: String, conformingTo contentType: UTType) -> URL {
        let url = appendingPathComponent(partialName)
        if let existing = UTType(filenameExtension: url.pathExtension), existing.conforms(to: contentType) {
            return url
        }
        return url.appendingPathExtension(for: contentType)
    }

    public mutating func appendPathComponent(_ partialName: String, conformingTo contentType: UTType) {
        self = appendingPathComponent(partialName, conformingTo: contentType)
    }

    public func appendingPathExtension(for contentType: UTType) -> URL {
        guard let fileExtension = contentType.preferredFilenameExtension else {
            return self
        }
        return appendingPathExtension(fileExtension)
    }

    public mutating func appendPathExtension(for contentType: UTType) {
        self = appendingPathExtension(for: contentType)
    }
}
