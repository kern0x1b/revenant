# SecKeyAlgorithms: the eighteen algorithm constants the port carries

iOS 6.1.3 exports none of the kSecKeyAlgorithm constants, and the held cache ladder first
exports ALL EIGHTEEN of them at iOS 11.0 - one release, so one object:
SecurityConstants11_0.m, because an object carries the API of one release.

The headers annotate them 10.0 and 13.0, which is when APPLE added them. The ladder is what a
held release first has, and the registry records the ladder.

## The values

A constant is a NAME. The value is the algid string a key signature answers with, and only the
host's own Security.framework knows what that is - so every one of the eighteen was written with a
placeholder, printed by tests/backports/host/security, and copied out of the DIFFERS line. Not one
value here was typed from a rule.

| constant | value |
| --- | --- |
| `kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA224AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA256AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA384AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA512AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA224AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA384AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA512AESGCM` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureDigestPSSSHA1` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureDigestPSSSHA224` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureDigestPSSSHA256` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureDigestPSSSHA384` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureDigestPSSSHA512` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureMessagePSSSHA1` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureMessagePSSSHA224` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureMessagePSSSHA256` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureMessagePSSSHA384` | `(read from the host at run time)` |
| `kSecKeyAlgorithmRSASignatureMessagePSSSHA512` | `(read from the host at run time)` |

## Safety

Reading eighteen constants touches nothing: there is no keychain write, no keychain query, no
identity lookup and no ephemeral key in this path, so the host needs no isolation. A member
that DID write would need an isolated temporary keychain file created and deleted by the test.
See DecisionTable.md for all 103 rows and where each one went.

