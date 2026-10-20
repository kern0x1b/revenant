# ACAccount.userFullName, iOS 7

`ACAccount` is an account in the system's account store: an identifier, an account type, a username,
a credential. iOS 7 added `userFullName`, the owner's name as the service knows it, so an application
can greet the person by name without a network round trip.

## What the release has

The account store of iOS 6.1.3 is the one Accounts.framework of that release talks to, and it holds
one kind of account: Sina Weibo. Its record is a handle and a name; there is no field in it that
carries the owner's full name, and no other account type is there to have one. So there is nothing
for the property to return on any account this release can produce.

That is also what Apple's own header says the property is for. `ACAccount.h` of the SDK 16.4:

> For accounts that support it (currently only Facebook accounts), you can get the user's full name
> for display purposes without having to talk to the network.

An account of this release is not an account that supports it, so `nil` is the documented answer
rather than a shortfall of this port. The property is also marked `API_UNAVAILABLE(macos)`, so the
host cannot be an oracle for it and none is claimed: the reasoning above is from the header and from
the state of the release, both named.

## What the port answers

`-userFullName` is `nil`, for every `ACAccount` there is, including one an application made itself
with `+[ACAccountStore ...]` and one restored from an archive. The accessor is added as a category on
the release's own class, so `respondsToSelector:` answers `YES` exactly as it does where the system
carries the field, and an application that checks before reading is told the truth about this port's
answer rather than about the API's existence.

## What it is not

It is not an empty string, not the username, and not the account's description dressed up as a name.
A name that is not the owner's name is worse than none: it would be shown to a person as though it
were.
