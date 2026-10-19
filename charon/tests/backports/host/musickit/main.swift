// The host check for a minted Apple Music developer token: mint one from a key generated here, write
// the three parts out, and let OpenSSL verify the signature. This is the end-to-end claim the
// README had to leave open - the ES256 half is the CloudKit C, and the base64url half is this
// module's own, and a JOSE verifier is what says the two together are a token.
//
// Named main.swift because that is the file whose top level is the entry point, as in the other two
// swiftc harnesses in this tree (combine/main.swift, realityfoundation/main.swift). The name it had
// (mint.mint.swift) made swiftc refuse the file outright: "expressions are not allowed at the top
// level", because only main.swift may hold them.
//
// The output directory is an argument, not a path written into this file: the run that builds this
// passes its own scratch directory, and the three part files land beside the key the caller made, so
// the checker that reads them reads the ones this program wrote. A fixed path under /tmp was in the
// first version of this file, and the checker read a different directory entirely - the two halves of
// the check had never been joined.
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
        // One part, and the marker the checker reads for "no token": the same signal either way, so
        // there is no second file to keep in step.
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
