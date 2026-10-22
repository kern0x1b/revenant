# 0009: The Telegram test is read-only source plus an overlay

Status: accepted, by the owner of the repository

## Context

The platform's proof is an application written for the current iOS SDK, running on an old device (see
[what revenant is for](../platform.md)). Building Telegram from source is one such proof. Its source is
someone else's, it moves on its own schedule, and a fix made inside it would not reach the next person who
builds it.

## Decision

- The test app's source is read-only to us. Nothing of it enters this repository, and nothing of it is pushed.
- Our side of the test is an overlay build driver outside this repository, plus the generic revenant tools the
  driver calls.
- A blocker the test hits is fixed in revenant's own layers (a component, a package, or the addon), as a
  generic change that any application could use. It is never fixed by editing the app's source.

## Consequences

- A change that is needed only to build one app is a sign the fix belongs in a layer, and the layer has to stay
  generic. The repository carries no app-specific code for it.
- Reproducing the test means the driver and the app's checkout, which are not in this repository. The
  repository's side of that test is only the tools.

## Enforced by

`repository/layout` (`tools/layout.lua`): no tracked path contains `telegram`, so the app's sources cannot be
committed under their own name.

## Not enforced

That no copy of the app's source is committed under another name, and that the overlay driver stays outside the
repository. Neither is visible from here; both are the owner's to keep.
