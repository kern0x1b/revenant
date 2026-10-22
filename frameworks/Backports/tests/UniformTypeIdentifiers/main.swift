#if !REVENANT_BACKPORT
import UniformTypeIdentifiers
#endif
import Foundation

let constants: [(String, UTType)] = [
    ("item", UTType.item),
    ("content", UTType.content),
    ("compositeContent", UTType.compositeContent),
    ("diskImage", UTType.diskImage),
    ("data", UTType.data),
    ("directory", UTType.directory),
    ("resolvable", UTType.resolvable),
    ("symbolicLink", UTType.symbolicLink),
    ("executable", UTType.executable),
    ("mountPoint", UTType.mountPoint),
    ("aliasFile", UTType.aliasFile),
    ("urlBookmarkData", UTType.urlBookmarkData),
    ("url", UTType.url),
    ("fileURL", UTType.fileURL),
    ("text", UTType.text),
    ("plainText", UTType.plainText),
    ("utf8PlainText", UTType.utf8PlainText),
    ("utf16ExternalPlainText", UTType.utf16ExternalPlainText),
    ("utf16PlainText", UTType.utf16PlainText),
    ("delimitedText", UTType.delimitedText),
    ("commaSeparatedText", UTType.commaSeparatedText),
    ("tabSeparatedText", UTType.tabSeparatedText),
    ("utf8TabSeparatedText", UTType.utf8TabSeparatedText),
    ("rtf", UTType.rtf),
    ("html", UTType.html),
    ("xml", UTType.xml),
    ("yaml", UTType.yaml),
    ("css", UTType.css),
    ("sourceCode", UTType.sourceCode),
    ("assemblyLanguageSource", UTType.assemblyLanguageSource),
    ("cSource", UTType.cSource),
    ("objectiveCSource", UTType.objectiveCSource),
    ("swiftSource", UTType.swiftSource),
    ("cPlusPlusSource", UTType.cPlusPlusSource),
    ("objectiveCPlusPlusSource", UTType.objectiveCPlusPlusSource),
    ("cHeader", UTType.cHeader),
    ("cPlusPlusHeader", UTType.cPlusPlusHeader),
    ("script", UTType.script),
    ("appleScript", UTType.appleScript),
    ("osaScript", UTType.osaScript),
    ("osaScriptBundle", UTType.osaScriptBundle),
    ("javaScript", UTType.javaScript),
    ("shellScript", UTType.shellScript),
    ("perlScript", UTType.perlScript),
    ("pythonScript", UTType.pythonScript),
    ("rubyScript", UTType.rubyScript),
    ("phpScript", UTType.phpScript),
    ("makefile", UTType.makefile),
    ("json", UTType.json),
    ("propertyList", UTType.propertyList),
    ("xmlPropertyList", UTType.xmlPropertyList),
    ("binaryPropertyList", UTType.binaryPropertyList),
    ("pdf", UTType.pdf),
    ("rtfd", UTType.rtfd),
    ("flatRTFD", UTType.flatRTFD),
    ("webArchive", UTType.webArchive),
    ("image", UTType.image),
    ("jpeg", UTType.jpeg),
    ("tiff", UTType.tiff),
    ("gif", UTType.gif),
    ("png", UTType.png),
    ("icns", UTType.icns),
    ("bmp", UTType.bmp),
    ("ico", UTType.ico),
    ("rawImage", UTType.rawImage),
    ("svg", UTType.svg),
    ("livePhoto", UTType.livePhoto),
    ("heif", UTType.heif),
    ("heic", UTType.heic),
    ("heics", UTType.heics),
    ("webP", UTType.webP),
    ("exr", UTType.exr),
    ("dng", UTType.dng),
    ("jpegxl", UTType.jpegxl),
    ("threeDContent", UTType.threeDContent),
    ("usd", UTType.usd),
    ("usdz", UTType.usdz),
    ("realityFile", UTType.realityFile),
    ("sceneKitScene", UTType.sceneKitScene),
    ("arReferenceObject", UTType.arReferenceObject),
    ("audiovisualContent", UTType.audiovisualContent),
    ("movie", UTType.movie),
    ("video", UTType.video),
    ("audio", UTType.audio),
    ("quickTimeMovie", UTType.quickTimeMovie),
    ("mpeg", UTType.mpeg),
    ("mpeg2Video", UTType.mpeg2Video),
    ("mpeg2TransportStream", UTType.mpeg2TransportStream),
    ("mp3", UTType.mp3),
    ("mpeg4Movie", UTType.mpeg4Movie),
    ("mpeg4Audio", UTType.mpeg4Audio),
    ("appleProtectedMPEG4Audio", UTType.appleProtectedMPEG4Audio),
    ("appleProtectedMPEG4Video", UTType.appleProtectedMPEG4Video),
    ("avi", UTType.avi),
    ("aiff", UTType.aiff),
    ("wav", UTType.wav),
    ("midi", UTType.midi),
    ("playlist", UTType.playlist),
    ("m3uPlaylist", UTType.m3uPlaylist),
    ("folder", UTType.folder),
    ("volume", UTType.volume),
    ("package", UTType.package),
    ("bundle", UTType.bundle),
    ("pluginBundle", UTType.pluginBundle),
    ("spotlightImporter", UTType.spotlightImporter),
    ("quickLookGenerator", UTType.quickLookGenerator),
    ("xpcService", UTType.xpcService),
    ("framework", UTType.framework),
    ("application", UTType.application),
    ("applicationBundle", UTType.applicationBundle),
    ("applicationExtension", UTType.applicationExtension),
    ("unixExecutable", UTType.unixExecutable),
    ("exe", UTType.exe),
    ("systemPreferencesPane", UTType.systemPreferencesPane),
    ("archive", UTType.archive),
    ("gzip", UTType.gzip),
    ("bz2", UTType.bz2),
    ("zip", UTType.zip),
    ("appleArchive", UTType.appleArchive),
    ("tarArchive", UTType.tarArchive),
    ("spreadsheet", UTType.spreadsheet),
    ("presentation", UTType.presentation),
    ("database", UTType.database),
    ("message", UTType.message),
    ("contact", UTType.contact),
    ("vCard", UTType.vCard),
    ("toDoItem", UTType.toDoItem),
    ("calendarEvent", UTType.calendarEvent),
    ("emailMessage", UTType.emailMessage),
    ("internetLocation", UTType.internetLocation),
    ("internetShortcut", UTType.internetShortcut),
    ("font", UTType.font),
    ("bookmark", UTType.bookmark),
    ("pkcs12", UTType.pkcs12),
    ("x509Certificate", UTType.x509Certificate),
    ("epub", UTType.epub),
    ("log", UTType.log),
    ("ahap", UTType.ahap),
    ("geoJSON", UTType.geoJSON),
    ("linkPresentationMetadata", UTType.linkPresentationMetadata),
]

let supertypeNames = ["item", "content", "data", "image", "movie", "audio", "text", "plainText", "sourceCode", "executable", "folder", "package", "url", "fileURL", "json", "pdf"]

func supertype(_ name: String) -> UTType {
    constants.first { $0.0 == name }!.1
}

func describe(_ name: String, _ type: UTType) -> String {
    let supers = type.supertypes.map { $0.identifier }.sorted().joined(separator: ",")
    let tags = type.tags.map { "\($0.key.rawValue)=\($0.value.sorted().joined(separator: ","))" }.sorted().joined(separator: ";")
    let fields = [
        name, type.identifier, "declared=\(type.isDeclared)", "dynamic=\(type.isDynamic)", "public=\(type.isPublic)",
        "ext=\(type.preferredFilenameExtension ?? "-")", "mime=\(type.preferredMIMEType ?? "-")", "local=\(type.localizedDescription ?? "-")",
        "version=\(String(describing: type.version))", "ref=\(String(describing: type.referenceURL))", "supers=\(supers)", "tags=\(tags)",
        "description=\(type.description)",
    ]
    return fields.joined(separator: " | ")
}

for (name, type) in constants {
    print(describe(name, type))
}

for (name, type) in constants {
    for parent in supertypeNames {
        print("conforms \(name) \(parent) \(type.conforms(to: supertype(parent))) isSubtype \(type.isSubtype(of: supertype(parent))) isSupertype \(type.isSupertype(of: supertype(parent)))")
    }
}

for identifier in ["public.jpeg", "PUBLIC.JPEG", "a.b", "", "notauti", "com.example.undeclared", "dyn.abc123", "dyn.", "public..x", "public.jpeg/x", "public.heic "] {
    let type = UTType(identifier)
    print("init \(identifier) -> \(type.map { $0.identifier } ?? "nil") declared=\(type?.isDeclared ?? false) dynamic=\(type?.isDynamic ?? false)")
}

for tag in ["jpg", "JPG", "JPEG", ".jpg", "", "heic", "mp4", "revenantzz9", "txt", "swift", "mov", "c", "cc"] {
    let plain = UTType(filenameExtension: tag)?.identifier ?? "nil"
    let image = UTType(filenameExtension: tag, conformingTo: .image)?.identifier ?? "nil"
    let movie = UTType(filenameExtension: tag, conformingTo: .movie)?.identifier ?? "nil"
    print("ext \(tag) plain=\(plain) image=\(image) movie=\(movie)")
}

for tag in ["image/png", "IMAGE/PNG", "", "text/plain", "text/plain;charset=utf-8", "text/plain; charset=utf-8", "application/x-revenant", "video/mp4", "audio/mpeg", "image/jpeg"] {
    let plain = UTType(mimeType: tag)?.identifier ?? "nil"
    let image = UTType(mimeType: tag, conformingTo: .image)?.identifier ?? "nil"
    print("mime \(tag) plain=\(plain) image=\(image)")
}

for tag in ["jpg", "png", "mp4", "txt", "revenantzz9", "c", ""] {
    let extensionTypes = UTType.types(tag: tag, tagClass: .filenameExtension, conformingTo: nil).map { $0.identifier }.sorted()
    let imageTypes = UTType.types(tag: tag, tagClass: .filenameExtension, conformingTo: .image).map { $0.identifier }.sorted()
    print("types ext \(tag) all=\(extensionTypes) image=\(imageTypes)")
}

for tag in ["image/png", "video/mp4", "application/x-revenant", ""] {
    let mimeTypes = UTType.types(tag: tag, tagClass: .mimeType, conformingTo: nil).map { $0.identifier }.sorted()
    print("types mime \(tag) all=\(mimeTypes)")
}

print("tag init ext \(UTType(tag: "jpg", tagClass: .filenameExtension, conformingTo: nil)?.identifier ?? "nil")")
print("tag init mime \(UTType(tag: "image/png", tagClass: .mimeType, conformingTo: nil)?.identifier ?? "nil")")
print("tag init empty \(UTType(tag: "", tagClass: .filenameExtension, conformingTo: nil)?.identifier ?? "nil")")
print("tag classes \(UTTagClass.filenameExtension.rawValue) \(UTTagClass.mimeType.rawValue)")

print("equal \(UTType("public.jpeg") == UTType.jpeg) hash \(Set([UTType.jpeg, UTType("PUBLIC.JPEG")!]).count)")
print("exported \(UTType(exportedAs: "com.example.thing", conformingTo: .image).conforms(to: .image)) imported \(UTType(importedAs: "com.example.imported").identifier)")

let url = URL(fileURLWithPath: "/tmp/revenant-uti/photo")
print("url jpeg \(url.appendingPathExtension(for: .jpeg).path)")
print("url item \(url.appendingPathExtension(for: .item).path)")
print("url png component \(URL(fileURLWithPath: "/tmp/revenant-uti").appendingPathComponent("photo", conformingTo: .png).path)")
print("url typed component \(URL(fileURLWithPath: "/tmp/revenant-uti").appendingPathComponent("photo.jpeg", conformingTo: .png).path)")
print("url extension component \(URL(fileURLWithPath: "/tmp/revenant-uti").appendingPathComponent("photo.jpeg", conformingTo: .jpeg).path)")

let encoder = JSONEncoder()
let roundTrip = try! JSONDecoder().decode([UTType].self, from: try! encoder.encode([UTType.jpeg, UTType.heic]))
print("json round trip \(roundTrip.map { $0.identifier })")
let decoded = try! JSONDecoder().decode([UTType].self, from: Data("[\"public.heic\",\"dyn.abc123\"]".utf8))
print("decoded \(decoded.map { $0.identifier })")
print("decode failure \((try? JSONDecoder().decode(UTType.self, from: Data("\"a.b\"".utf8))) == nil)")
