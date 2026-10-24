import CBoringSSL

func reasonText(_ code: UInt32) -> String {
    guard let text = ERR_reason_error_string(code) else {
        return "none"
    }
    return String(cString: text)
}

func describe(_ label: String, _ length: Int32) {
    if length > 0 {
        print("x509 \(label) ok \(length)")
        return
    }
    let code = ERR_get_error()
    print("x509 \(label) failed \(length) code \(code) \(reasonText(code))")
}

certificateBytes.withUnsafeBufferPointer { buffer in
    var input: UnsafePointer<UInt8>? = buffer.baseAddress
    guard let x509 = d2i_X509(nil, &input, buffer.count) else {
        let code = ERR_get_error()
        print("x509 parse failed code \(code) \(reasonText(code))")
        return
    }
    print("x509 parse ok")
    describe("subject", i2d_X509_NAME(X509_get_subject_name(x509), nil))
    describe("issuer", i2d_X509_NAME(X509_get_issuer_name(x509), nil))
    describe("notBefore", i2d_ASN1_TIME(X509_get0_notBefore(x509), nil))
    describe("notAfter", i2d_ASN1_TIME(X509_get0_notAfter(x509), nil))
    describe("pubkey", i2d_X509_PUBKEY(X509_get_X509_PUBKEY(x509), nil))
    for index in 0..<Int(X509_get_ext_count(x509)) {
        describe("extension \(index)", i2d_X509_EXTENSION(X509_get_ext(x509, Int32(index)), nil))
    }
    var output: UnsafeMutablePointer<UInt8>? = nil
    let length = i2d_X509(x509, &output)
    describe("certificate", length)
    if length > 0, let output {
        let same = Int(length) == buffer.count && memcmp(output, buffer.baseAddress!, buffer.count) == 0
        print("x509 roundtrip \(same ? "identical" : "differs")")
    }
    X509_free(x509)
}
