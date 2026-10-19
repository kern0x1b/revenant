import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@_cdecl("charonMintAndWrite")
func charonMintAndWrite() {
    let arguments = CommandLine.arguments
    guard arguments.count >= 5 else {
        print("usage: mint <key.pem> <key identifier> <team identifier> <output directory>")
        exit(2)
    }
    let pem = try! String(contentsOfFile: arguments[1], encoding: .utf8)
    let directory = arguments[4]
    let path: (String) -> String = { name in directory + "/" + name }
    guard let token = MusicDeveloperToken.mint(keyIdentifier: arguments[2],
                                              teamIdentifier: arguments[3],
                                              privateKeyPEM: pem) else {
        FileManager.default.createFile(atPath: path("part0.txt"), contents: Data("nil".utf8))
        return
    }
    let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    for (index, part) in parts.enumerated() {
        FileManager.default.createFile(atPath: path("part\(index).txt"), contents: Data(part.utf8))
    }
    print("minted \(parts.count) parts")
}

charonMintAndWrite()
