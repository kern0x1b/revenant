@_exported import Crypto

extension Curve25519.KeyAgreement.PrivateKey {
    public typealias PublicKey = Curve25519.KeyAgreement.PublicKey
}

extension P256.KeyAgreement.PrivateKey {
    public typealias PublicKey = P256.KeyAgreement.PublicKey
}

extension P384.KeyAgreement.PrivateKey {
    public typealias PublicKey = P384.KeyAgreement.PublicKey
}

extension P521.KeyAgreement.PrivateKey {
    public typealias PublicKey = P521.KeyAgreement.PublicKey
}

extension MLKEM768.PrivateKey {
    public typealias PublicKey = MLKEM768.PublicKey
}

extension MLKEM1024.PrivateKey {
    public typealias PublicKey = MLKEM1024.PublicKey
}

extension XWingMLKEM768X25519.PrivateKey {
    public typealias PublicKey = XWingMLKEM768X25519.PublicKey
}
