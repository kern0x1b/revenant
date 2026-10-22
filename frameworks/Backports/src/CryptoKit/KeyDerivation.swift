import Foundation

public struct HKDF<H>: Sendable where H: HashFunction {
    public static func deriveKey(inputKeyMaterial: SymmetricKey, outputByteCount: Int) -> SymmetricKey {
        deriveKey(inputKeyMaterial: inputKeyMaterial, salt: Data(), info: Data(), outputByteCount: outputByteCount)
    }

    public static func deriveKey<Info>(inputKeyMaterial: SymmetricKey, info: Info, outputByteCount: Int) -> SymmetricKey where Info: DataProtocol {
        deriveKey(inputKeyMaterial: inputKeyMaterial, salt: Data(), info: info, outputByteCount: outputByteCount)
    }

    public static func deriveKey<Salt>(inputKeyMaterial: SymmetricKey, salt: Salt, outputByteCount: Int) -> SymmetricKey where Salt: DataProtocol {
        deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, info: Data(), outputByteCount: outputByteCount)
    }

    public static func deriveKey<Salt, Info>(inputKeyMaterial: SymmetricKey, salt: Salt, info: Info, outputByteCount: Int) -> SymmetricKey where Salt: DataProtocol, Info: DataProtocol {
        let pseudoRandomKey = extract(inputKeyMaterial: inputKeyMaterial, salt: salt)
        return expand(pseudoRandomKey: SymmetricKey(data: pseudoRandomKey), info: info, outputByteCount: outputByteCount)
    }

    public static func extract<Salt>(inputKeyMaterial: SymmetricKey, salt: Salt?) -> HashedAuthenticationCode<H> where Salt: DataProtocol {
        let key = SymmetricKey(data: salt.map { Data($0) } ?? Data())
        let material = inputKeyMaterial.withUnsafeBytes { Data($0) }
        return HMAC<H>.authenticationCode(for: material, using: key)
    }

    public static func expand<PRK, Info>(pseudoRandomKey prk: PRK, info: Info?, outputByteCount: Int) -> SymmetricKey where PRK: ContiguousBytes, Info: DataProtocol {
        precondition(outputByteCount <= 255 * H.Digest.byteCount, "HKDF output is longer than 255 hash blocks")
        let key = SymmetricKey(data: prk)
        let shared = info.map { Data($0) } ?? Data()
        var output = Data()
        var block = Data()
        var counter: UInt8 = 1
        while output.count < outputByteCount {
            var message = block
            message += shared
            message.append(counter)
            block = Data(HMAC<H>.authenticationCode(for: message, using: key))
            output += block
            counter &+= 1
        }
        return SymmetricKey(data: output.prefix(outputByteCount))
    }
}
