# The Tencent Weibo names, iOS 7

`ACAccountTypeIdentifierTencentWeibo` names an account type, and `ACTencentWeiboAppIdKey` is the key
an options dictionary carries the application's Tencent App ID under. Both arrived in iOS 7 and both
were deprecated in iOS 11, when Apple asked applications to use the Weibo SDKs instead.

## What the release has

iOS 6.1.3 ships Accounts with `ACAccount` and the account types of Sina Weibo and Facebook — the
`Accounts` image of its armv7 shared cache exports `_OBJC_CLASS_$_ACAccount` — and no Tencent Weibo
type. So an application that names either of these two symbols is killed by dyld before its `main`,
which is the one thing a backport must never leave in place.

Both are therefore carried, with the texts Accounts itself gives them. Read out of a real cache
rather than taken from a header, with `tools/corpus/cache-value.lua` over the arm64e shared cache of iOS 18.0
through the symbols of Accounts:

| symbol | value |
| --- | --- |
| `_ACAccountTypeIdentifierTencentWeibo` | `com.apple.account.tencentweibo` |
| `_ACTencentWeiboAppIdKey` | `ACTencentWeiboAppIdKey` |
| `_ACAccountTypeIdentifierSinaWeibo` (control) | `com.apple.sinaweibo` |

The control is the point of the table: the identifier of the type the release *does* have reads as
the same shape of string, so the value above is the one Accounts uses and not a spelling of the
symbol.

## What an application gets

- `+[ACAccountStore accountTypeWithIdentifier:]` answers `nil` for
  `ACAccountTypeIdentifierTencentWeibo`, exactly as it answers for any identifier the release has no
  type under. The identifier is a name, not an account: nothing is created by naming it.
- An options dictionary built with `ACTencentWeiboAppIdKey` has the key a later release's `accountsd`
  reads, so it is the right shape; the release's own `accountsd` never sees it, because the release
  has no Tencent Weibo type to ask access for.

## What it is not

Neither constant is a working account type. They make an application load and let it build the
dictionary it would build on a release that has the service; they do not give it an account, a
credential or a network conversation, and the port does not pretend to.
