# CSUserQueryContext, CSUserQuery and CSSuggestion

## CSUserQueryContext (implemented)

`CSUserQueryContext` is a `CSSearchQueryContext` with five properties of its own. The port is
`CoreSpotlight/CSUserQueryContext.m`. The answers are the host's, measured with
`tests/backports/host/corespotlight-userquery` (11 lines, identical on both sides; a planted control that drops the copy of
`disableSemanticSearch` differs on 2 lines).

The SDK declares `disableSemanticSearch` and `maxRankedResultCount` for iOS 18.0 and macOS 15.0; the others for iOS 16.0.
The port does not gate on the release; the registry row's `introduced` is the class's 16.0.

- Defaults from `+userQueryContext`: `enableRankedResults` NO, `disableSemanticSearch` NO, `maxResultCount` 0,
  `maxSuggestionCount` 0, `maxRankedResultCount` 100.
- `+userQueryContextWithCurrentSuggestion:nil` gives the factory's values with `maxSuggestionCount` 10. A non-nil suggestion is
  not measured: a `CSSuggestion` comes only from a user query, which the port does not answer (below).
- Defaults from `-init` (measured, the `init` line of the differential): all five are zero, including
  `maxRankedResultCount`, which only the factory sets to 100.
- Copy: the copy is a `CSUserQueryContext` and keeps `disableSemanticSearch`, `maxSuggestionCount` and
  `maxRankedResultCount`. It drops `enableRankedResults` and `maxResultCount`, which read back as their initial values.
- Coding (keyed archive): only `disableSemanticSearch` survives; the other four subclass properties decode as zero,
  `maxRankedResultCount` included. The port codes `disableSemanticSearch` under its own key and decodes it.
- Identity: `isEqual:` is pointer identity, as measured.

## CSUserQuery (owed)

The SDK declares `CSUserQuery` as a `CSSearchQuery` subclass, with `initWithUserQueryString:userQueryContext:`,
`foundSuggestionsHandler`, `foundSuggestionCount`, `start`, `cancel`, `prepare` and `prepareProtectionClasses:` (iOS 18.0),
and `userEngagedWithItem:visibleItems:userInteractionType:` and `userEngagedWithSuggestion:visibleSuggestions:userInteractionType:`
(iOS 18.0). The port has no `CSUserQuery` class (none in `CoreSpotlight/`), so an application that uses it gets no class at
all. Owed: the suggestion engine, the free-text answers, and the engagement callbacks. The SDK's declaration is the
measurement of the surface; the answers are not measured.

## CSSuggestion (owed)

The SDK declares `CSSuggestion` (NSObject, NSSecureCoding, NSCopying) with `localizedAttributedSuggestion`, `suggestionKind`
(`CSSuggestionKind`: None 0, Custom 1, Default 2), `compare:` and `compareByRank:`, and the attribute name
`CSSuggestionHighlightAttributeName`. Instances come only from a `CSUserQuery`, and the port answers no suggestions, so it
never has one. Owed for the same reason as `CSUserQuery`.
