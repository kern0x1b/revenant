# Access control of keychain items and shared web credentials, iOS 8.0 and 9.0

iOS 8.0 added access control to the keychain (`SecAccessControlCreateWithFlags`, `kSecAttrAccessControl`, the
accessibility `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, the prompt `kSecUseOperationPrompt`) and shared web
credentials (`SecAddSharedWebCredential`, `SecRequestSharedWebCredential`, `SecCreateSharedWebCredentialPassword`,
`kSecSharedPassword`); iOS 9.0 added `kSecUseAuthenticationUI` with its three values and `kSecUseAuthenticationContext`.

Source: Security of the arm64 shared cache of iOS 12.0 - the constants `_kSecAttrAccessControl` (`accc`),
`_kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` (`akpu`), `_kSecUseOperationPrompt` (`u_OpPrompt`),
`_kSecUseNoAuthenticationUI` (`u_NoAuthUI`), `_kSecSharedPassword` (`spwd`), `_kSecUseAuthenticationUI` (`u_AuthUI`)
with `u_AuthUIA`, `u_AuthUIF` and `u_AuthUIS`, and `_kSecUseAuthenticationContext` (`u_AuthCtx`), each a constant
string read from the image; the host's Security, sampled fifty thousand times, for the passwords; an iPad 2 running 6.1.3
with an application that holds a keychain access group for what the keychain does.

## What it is

The constants are keys and values of the dictionaries `SecItemAdd`, `SecItemCopyMatching` and `SecItemDelete` take. The
access control object says which authentication an item needs. The shared web credential functions store and read a
password against a domain of the application's associated domains, through a service of the system, and hand their answers to
a block. `SecCreateSharedWebCredentialPassword` makes a password of fifteen characters, `xxx-xxx-xxx-xxx`, twelve chosen at
random from the digits 2 to 9, the letters A to Z without I and O, and the letters a to z without i, j and l, with at least
one digit, one capital and one small letter.

## Where iOS 6 differs

iOS 6.1.3 has none of the functions, and its keychain refuses every one of the keys. On the iPad 2 an add with
`kSecAttrAccessible` set to `akpu`, with an `accc` value, and a query with `u_OpPrompt`, `u_AuthCtx` or `u_AuthUI` (with
any of the three values and with a value that is none) each answers -50, `errSecParam`, as an unknown key such as
`zzzz` does; the accessibility `aku` is accepted. The keychain of iOS 6 knows the `sync` key, which is why
`kSecAttrSynchronizable` is carried, and none of these.

So the constants are carried under their own names and values, and what an application does with them is refused by the
keychain with -50, which it can handle, where a missing constant would be a NULL that a dictionary of the application
cannot hold. `SecAccessControlCreateWithFlags` answers NULL with an error in `NSOSStatusErrorDomain` of the code
`errSecUnimplemented` (-4): the release has no such object, and an object that could not be used would be worse than
none. The shared web credential functions cannot use a service the release has not: `SecAddSharedWebCredential` calls
its block with that error, off the calling thread, and `SecRequestSharedWebCredential` calls its block with an empty array and
no error, as a device with no saved credential would, where an error would put a failure in front of a user who has
nothing wrong. Whether iOS 12 calls the block of the request on a queue of its own was not read, and a global queue is used.
`SecCreateSharedWebCredentialPassword` is made here, from the rules above, which were measured on the host, not read
from iOS 12. `SecAccessControlGetTypeID`, `kSecAttrTokenID` and its Secure Enclave value stay absent: there is no such type and
no Secure Enclave.
