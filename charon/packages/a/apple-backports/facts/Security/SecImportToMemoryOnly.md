# kSecImportToMemoryOnly (iOS 18.0)

The import option that asks for the imported items to stay in memory, not to be written to the keychain.

Measured:

- Value: the CFString "memory", which is what the host's own Security.framework returns for the name (dlsym, compared as
  a string by tests/backports/host/commoncrypto/differential-constants.c, 90 constants, failures 0).
- 6.1.3: the armv7 Security image of the 6.1.3 cache exports no symbol named kSecImportToMemoryOnly
  (`tools/image-exports.lua 6.1.3 armv7 "Security.framework/Security" ""`, 660 exports).

Behaviour in this port: a grep of the port's sources finds the name only in its own file (SecurityNames180.m), and no
import function (SecPKCS12Import, SecItemImport) is in the port's sources. Nothing reads the option, so the constant is
inert. Whether an import needs a keychain on this release was not measured in this step.

Upstream: apple-open-source Security (APSL-2.0) declares the name in SecImportExport.c as an upstream-only row; the value
is the one the host carries, so the port takes the same string.
