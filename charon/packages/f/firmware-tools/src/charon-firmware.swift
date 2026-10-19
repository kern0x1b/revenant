import CommonCrypto
import CryptoKit
import Foundation

func fail(_ text: String) -> Never {
    FileHandle.standardError.write(Data((text + "\n").utf8))
    exit(1)
}

func bytes(hex: String) -> [UInt8] {
    var result: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        guard let byte = UInt8(hex[index..<next], radix: 16) else { fail("\(hex) is not a hexadecimal key") }
        result.append(byte)
        index = next
    }
    return result
}

func bigEndian<T: FixedWidthInteger>(_ data: Data, at offset: Int, as type: T.Type) -> T {
    data.subdata(in: offset..<offset + MemoryLayout<T>.size).reduce(T(0)) { $0 << 8 | T($1) }
}

func littleEndian<T: FixedWidthInteger>(_ data: Data, at offset: Int, as type: T.Type) -> T {
    data.subdata(in: offset..<offset + MemoryLayout<T>.size).reversed().reduce(T(0)) { $0 << 8 | T($1) }
}

func filevault(input: String, key: String, output: String) {
    let material = bytes(hex: key)
    guard material.count == 36 else { fail("a FileVault image key is 36 bytes (AES-128 and HMAC-SHA1), not \(material.count)") }
    let aesKey = Array(material[0..<16]), hmacKey = Array(material[16..<36])
    guard let source = FileHandle(forReadingAtPath: input) else { fail("cannot read \(input)") }
    let header = source.readData(ofLength: 72)
    guard header.count == 72, header.prefix(8) == Data("encrcdsa".utf8) else { fail("\(input) is not an encrcdsa image") }
    guard bigEndian(header, at: 8, as: UInt32.self) == 2 else { fail("\(input) is an encrcdsa image of a version other than 2") }
    let blockSize = Int(bigEndian(header, at: 52, as: UInt32.self))
    let dataSize = bigEndian(header, at: 56, as: UInt64.self)
    let dataOffset = bigEndian(header, at: 64, as: UInt64.self)
    guard FileManager.default.createFile(atPath: output, contents: nil), let sink = FileHandle(forWritingAtPath: output) else { fail("cannot write \(output)") }
    var cryptor: CCCryptorRef?
    guard CCCryptorCreate(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), 0, aesKey, aesKey.count, nil, &cryptor) == kCCSuccess else { fail("cannot set up AES") }
    defer { CCCryptorRelease(cryptor) }
    try? source.seek(toOffset: dataOffset)
    let batch = 256
    var remaining = dataSize, chunk: UInt32 = 0
    var plain = [UInt8](repeating: 0, count: blockSize)
    var iv = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    while remaining > 0 {
        let read = source.readData(ofLength: blockSize * batch)
        guard read.count > 0, read.count % blockSize == 0 else { fail("\(input) ends before its declared size") }
        var out = Data(capacity: read.count)
        read.withUnsafeBytes { (cipher: UnsafeRawBufferPointer) in
            for start in stride(from: 0, to: read.count, by: blockSize) where remaining > 0 {
                var number = chunk.bigEndian
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), hmacKey, hmacKey.count, &number, 4, &iv)
                CCCryptorReset(cryptor, iv)
                var moved = 0
                CCCryptorUpdate(cryptor, cipher.baseAddress! + start, blockSize, &plain, blockSize, &moved)
                let kept = Int(min(UInt64(blockSize), remaining))
                out.append(plain, count: kept)
                remaining -= UInt64(kept)
                chunk += 1
            }
        }
        sink.write(out)
    }
    sink.closeFile()
}

func aeaKey(input: String) {
    guard let source = FileHandle(forReadingAtPath: input) else { fail("cannot read \(input)") }
    let header = source.readData(ofLength: 12)
    guard header.count == 12, header.prefix(4) == Data("AEA1".utf8) else { fail("\(input) is not an Apple Encrypted Archive") }
    let authLength = Int(littleEndian(header, at: 8, as: UInt32.self))
    let auth = source.readData(ofLength: authLength)
    var fields: [String: Data] = [:]
    var offset = 0
    while offset + 4 <= auth.count {
        let length = Int(littleEndian(auth, at: offset, as: UInt32.self))
        guard length >= 4, offset + length <= auth.count else { break }
        let entry = auth.subdata(in: offset + 4..<offset + length)
        if let separator = entry.firstIndex(of: 0) {
            fields[String(decoding: entry[entry.startIndex..<separator], as: UTF8.self)] = entry.subdata(in: separator + 1..<entry.endIndex)
        }
        offset += length
    }
    guard let urlData = fields["com.apple.wkms.fcs-key-url"], let url = URL(string: String(decoding: urlData, as: UTF8.self)),
          let responseData = fields["com.apple.wkms.fcs-response"],
          let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: String],
          let enc = response["enc-request"].flatMap({ Data(base64Encoded: $0) }),
          let wrapped = response["wrapped-key"].flatMap({ Data(base64Encoded: $0) }) else {
        fail("\(input) names no wkms key in its authentication data")
    }
    guard let pem = try? String(contentsOf: url, encoding: .utf8) else { fail("cannot fetch the archive key from \(url)") }
    do {
        let privateKey = try P256.KeyAgreement.PrivateKey(pemRepresentation: pem)
        var recipient = try HPKE.Recipient(privateKey: privateKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: Data(), encapsulatedKey: enc)
        print(try recipient.open(wrapped).base64EncodedString())
    } catch {
        fail("cannot unwrap the key of \(input): \(error)")
    }
}

let arguments = CommandLine.arguments
switch (arguments.count > 1 ? arguments[1] : "", arguments.count) {
case ("filevault", 5): filevault(input: arguments[2], key: arguments[3], output: arguments[4])
case ("aea-key", 3): aeaKey(input: arguments[2])
default: fail("usage: charon-firmware filevault IMAGE HEXKEY OUTPUT | charon-firmware aea-key ARCHIVE")
}
