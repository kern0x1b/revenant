import CommonCrypto
import Foundation

enum Insecure {
  struct Digest: Sequence {
    let bytes: [UInt8]

    func makeIterator() -> IndexingIterator<[UInt8]> {
      return bytes.makeIterator()
    }
  }

  struct MD5 {
    private var context = CC_MD5_CTX()

    init() {
      CC_MD5_Init(&context)
    }

    mutating func update<D: DataProtocol>(data: D) {
      for region in data.regions {
        region.withUnsafeBytes { buffer in
          _ = CC_MD5_Update(&context, buffer.baseAddress, CC_LONG(buffer.count))
        }
      }
    }

    mutating func finalize() -> Digest {
      var out = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
      CC_MD5_Final(&out, &context)
      return Digest(bytes: out)
    }

    static func hash<D: DataProtocol>(data: D) -> Digest {
      var hasher = MD5()
      hasher.update(data: data)
      return hasher.finalize()
    }
  }
}
