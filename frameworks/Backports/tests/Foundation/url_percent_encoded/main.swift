import Foundation

func show(_ value: String?) -> String {
    return value.map { "<" + $0 + ">" } ?? "nil"
}

func describe(_ url: URL) -> String {
    var fields: [String] = []
    for encoded in [true, false] {
        fields.append("host=" + show(url.host(percentEncoded: encoded)))
        fields.append("user=" + show(url.user(percentEncoded: encoded)))
        fields.append("password=" + show(url.password(percentEncoded: encoded)))
        fields.append("path=" + show(url.path(percentEncoded: encoded)))
        fields.append("query=" + show(url.query(percentEncoded: encoded)))
        fields.append("fragment=" + show(url.fragment(percentEncoded: encoded)))
    }
    fields.append("default=" + show(url.host()) + show(url.query()))
    return fields.joined(separator: " ")
}

func locations(_ url: URL) -> String {
    return "absolute=" + url.absoluteString + " path=" + url.path + " directory=" + String(url.hasDirectoryPath) + " base=" + show(url.baseURL?.absoluteString)
}

func isRepresentableByCoreFoundationURL(_ text: String) -> Bool {
    return text.unicodeScalars.allSatisfy { $0.isASCII } && !text.hasPrefix(":")
}

let encodedInternationalHosts = [
    "https://%E4%BE%8B%E5%AD%90.%E6%B5%8B%E8%AF%95/%E8%B7%AF",
    "https://%C3%9Cn%C3%AFcode.example/",
    "https://%C3%BCn%C3%AFcode.example:8080/",
    "https://%E4%BE%8B%E5%AD%90.com/",
    "https://EXAMPLE.COM/Path?Q=1#F",
    "https://user:p%40ss@host.example:81/a%20b?c=%E2%9C%93#d%2Fe",
    "https://[::1]/",
    "https://[fe80::1%25en0]:99/",
    "https://%FF.example/",
    "https://a%2Fb.example/",
    "https://host.example/%FF%FE",
]

let corpus = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
var index = 0
let lines = corpus.split(separator: "\n", omittingEmptySubsequences: true).map { $0 == "<empty>" ? "" : String($0) }
for text in lines + encodedInternationalHosts where isRepresentableByCoreFoundationURL(text) {
    if let url = URL(string: text) {
        print("\(index)\t" + text + "\t" + describe(url))
    } else {
        print("\(index)\t" + text + "\tnil")
    }
    index += 1
}

let base = URL(fileURLWithPath: "/tmp/revenant-base/", isDirectory: true)
let paths = ["", "/", "/tmp", "/tmp/", "tmp", "a/b", "a/b/", "../x", "./y/", "/tmp/with space", "/tmp/ü/ö", "/nonexistent-revenant-path", "/nonexistent-revenant-path/"]
for path in paths {
    print("file\t" + show(path) + "\tdefault\t" + locations(URL(filePath: path)))
    print("file\t" + show(path) + "\tisDirectory\t" + locations(URL(filePath: path, directoryHint: .isDirectory)))
    print("file\t" + show(path) + "\tnotDirectory\t" + locations(URL(filePath: path, directoryHint: .notDirectory)))
    print("file\t" + show(path) + "\tcheckFileSystem\t" + locations(URL(filePath: path, directoryHint: .checkFileSystem)))
    print("file\t" + show(path) + "\tinferFromPath\t" + locations(URL(filePath: path, directoryHint: .inferFromPath)))
    print("file\t" + show(path) + "\trelative\t" + locations(URL(filePath: path, relativeTo: base)))
    print("file\t" + show(path) + "\trelativeDirectory\t" + locations(URL(filePath: path, directoryHint: .isDirectory, relativeTo: base)))
}

let directories: [(String, URL)] = [
    ("home", URL.homeDirectory),
    ("temporary", URL.temporaryDirectory),
    ("caches", URL.cachesDirectory),
    ("applicationSupport", URL.applicationSupportDirectory),
    ("library", URL.libraryDirectory),
    ("documents", URL.documentsDirectory),
    ("desktop", URL.desktopDirectory),
    ("downloads", URL.downloadsDirectory),
    ("movies", URL.moviesDirectory),
    ("music", URL.musicDirectory),
    ("pictures", URL.picturesDirectory),
    ("sharedPublic", URL.sharedPublicDirectory),
    ("application", URL.applicationDirectory),
    ("user", URL.userDirectory),
    ("current", URL.currentDirectory()),
]
for (name, url) in directories {
    print("directory\t" + name + "\t" + locations(url))
}
for user in [NSUserName(), "root", "revenant-no-such-user"] {
    print("directory\thome(forUser: " + user + ")\t" + (URL.homeDirectory(forUser: user).map(locations) ?? "nil"))
}
