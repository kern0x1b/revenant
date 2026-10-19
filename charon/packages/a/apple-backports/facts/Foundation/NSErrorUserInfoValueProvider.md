# +[NSError setUserInfoValueProviderForDomain:provider:], iOS 9

Introduced in iOS 9.0: a block that answers, for the errors of one domain, the values that are looked up lazily instead of being stored in the user info: the localized description, failure reason,
recovery suggestion and options, the recovery attempter and the help anchor.

Source: the host's own Foundation (`host/errorprovider/run.sh`) over `device/errorprovider-cases.m`, and the same cases on iOS 6 in `device/errorprovider.m`. The system asks the provider only for
the key of the getter that was called and only when the user info has no value for it; `-userInfo` stays as it was and a lookup in it does not ask; a value in the user info wins; other domains are
not asked; a description from the provider replaces the failure reason of the user info, and a failure reason from the provider composes with the standard description text; setting a provider again
replaces it and `nil` removes it; a copy of an error is answered too; the underlying error is not consulted. Returning `nil` gives the usual fallback.

`+userInfoValueProviderForDomain:` answers the same block object that was set for a domain
(compared by identity), `nil` for a domain nothing was ever set for, and `nil` again once the
domain's provider is cleared by setting `nil` - measured with a small probe against the host's
own Foundation and matched by the backport identically in all three cases.

## How the port does it

The six getters of `NSError` are replaced at load time by ones that ask the provider for their key, when the release has no such method on the class, before the release's own answer. The providers
are kept by domain and guarded by a lock. The description with a failure reason from the provider is composed by the release's own code, asking it about an error that holds the reason.
