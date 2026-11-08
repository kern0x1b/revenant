import Foundation

extension URL {
    private static func directory(_ directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> URL {
        return URL(filePath: NSSearchPathForDirectoriesInDomains(directory, domain, true)[0], directoryHint: .isDirectory)
    }

    public static var homeDirectory: URL {
        return URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
    }

    public static func homeDirectory(forUser user: String) -> URL? {
        return NSHomeDirectoryForUser(user).map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    public static var temporaryDirectory: URL {
        return URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
    }

    public static var cachesDirectory: URL {
        return directory(.cachesDirectory, in: .userDomainMask)
    }

    public static var applicationSupportDirectory: URL {
        return directory(.applicationSupportDirectory, in: .userDomainMask)
    }

    public static var libraryDirectory: URL {
        return directory(.libraryDirectory, in: .userDomainMask)
    }

    public static var documentsDirectory: URL {
        return directory(.documentDirectory, in: .userDomainMask)
    }

    public static var desktopDirectory: URL {
        return directory(.desktopDirectory, in: .userDomainMask)
    }

    public static var downloadsDirectory: URL {
        return directory(.downloadsDirectory, in: .userDomainMask)
    }

    public static var moviesDirectory: URL {
        return directory(.moviesDirectory, in: .userDomainMask)
    }

    public static var musicDirectory: URL {
        return directory(.musicDirectory, in: .userDomainMask)
    }

    public static var picturesDirectory: URL {
        return directory(.picturesDirectory, in: .userDomainMask)
    }

    public static var sharedPublicDirectory: URL {
        return directory(.sharedPublicDirectory, in: .userDomainMask)
    }

    public static var applicationDirectory: URL {
        return directory(.applicationDirectory, in: .localDomainMask)
    }

    public static var userDirectory: URL {
        return directory(.userDirectory, in: .localDomainMask)
    }

    public static func currentDirectory() -> URL {
        return URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
    }
}
