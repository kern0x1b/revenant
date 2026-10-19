# AuthenticationServices' string constants

Every `NSString *const` the AuthenticationServices headers declare, with the value a real
AuthenticationServices gives it. There are 29, and the way each was read differs by two cases, which
is why this file exists rather than the HomeKit one.

## 26 of them: out of a dyld cache

`AuthenticationServices.framework` of the **16.0 arm64e** and **18.0 arm64e** shared caches, read with
`modules/apple/dyld.lua`: the symbol's own pointer resolved through the cache's slide information, then
the `__CFConstantString`'s `char *` at +16 and its length at +24, with the bytes at that address
agreeing with the length in every case. Both caches agree on all 24 of the symbols they hold.

Two of them are the release's own name rather than a domain, and that is Apple's, measured:

    ASCredentialIdentityStoreErrorDomain = ASCredentialIdentityStoreErrorDomain
    ASExtensionErrorDomain               = ASExtensionErrorDomain

## Three of them: out of the host, with dlsym

`ASGeneratedPasswordKindStrong`, `ASGeneratedPasswordKindAlphanumeric` and
`ASGeneratedPasswordKindPassphrase` arrived in **iOS 26.2**, and no dyld cache on this machine is that
new — the ladder stops at 18.0. The **host's own macOS 27.0** carries them, though, and they were read
out of its framework with `dlsym`, the same three steps, and the same length cross-check:

| constant | value | length field | bytes |
| --- | --- | --- | --- |
| `ASGeneratedPasswordKindStrong` | `STRONG` | 6 | 6 |
| `ASGeneratedPasswordKindAlphanumeric` | `ALPHANUMERIC` | 12 | 12 |
| `ASGeneratedPasswordKindPassphrase` | `PASSPHRASE` | 10 | 10 |

This retracts what `facts/HomeKit/HMConstants.md` said about them — that there was no release to read
them from and the port would not invent them. The refusal to invent was right; the claim that nothing
held them was wrong, because the host does.

## What the rest of the constant surface is

The 49 `undecided` rows of AuthenticationServices' constant surface are Swift-only names
(`ASContactIdentifier.email`, `ASImportableCredential.passkey`, `ASPasskeyCredentialExtensionInput.registration`
and the rest): they are declared in a Swift module this port builds no armv7 module for, so nothing
here can place them, and the ledger says so. They are not string constants of the Objective-C surface
and nothing in this delivery claims them.

## One release per object file

`ASConstants12_0.m` through `ASConstants26_2.m`, named for the release each constant arrived in.
`tools/release-split.lua` walks the real cache ladder and agrees:

    release-split: clean, every object file's symbols first-appear in one release
                   (6 files, 29 symbols, 47 releases checked)
