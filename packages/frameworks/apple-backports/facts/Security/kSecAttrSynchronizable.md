# The synchronizable keychain attribute, iOS 7.0

iOS 7.0 added `kSecAttrSynchronizable` to the attributes of a keychain item, for an item
that iCloud Keychain carries to the user's other devices, and `kSecAttrSynchronizableAny`
as the value of a query that matches an item whether it is synchronizable or not.

Source: Security of the arm64 shared cache of iOS 12.0 - `_kSecAttrSynchronizable` at
`0x1b01c2730` and `_kSecAttrSynchronizableAny` at `0x1b01c2a58`, each a constant string
read from the image: `sync` and `syna`. An iPad 2 running 6.1.3, with an application
signed for a keychain access group, for what `SecItemAdd`, `SecItemCopyMatching` and
`SecItemDelete` do with the attribute.

## What it is

The two names are constant strings that are the keys and the value the keychain service
takes. The attribute is a key of an item's dictionary, with a boolean for a
synchronizable item or not, and `syna` in a query for either.

## Where iOS 6 differs

The keychain of iOS 6.1.3 takes the key as it is and does nothing with it. On the iPad 2
an item added with `sync` true, with `sync` false or with no `sync` is added, is found by a
query with `sync` true, false, `syna` or no key alike, and is deleted the same way. There is
no iCloud Keychain in the release, so an item that an application marks synchronizable
stays on the device and is never carried anywhere, and a query for synchronizable items
finds the items of the device. That is what an application that only reads back what it
wrote needs, and it is not what an application that waits for another device's items gets.

So this package carries the two names and nothing else, and it does not change what
`SecItem` does with them.

The neighbouring attributes are not carried. On the same iPad 2 a query that names
`kSecUseAuthenticationUI` (`u_AuthUI`, with the value `u_AuthUIF`) and an item added with
`kSecAttrTokenID` (`tkid`, with `com.apple.setoken`) are refused with the error -50, which is
what a carried constant would hand an application. They are absent.
