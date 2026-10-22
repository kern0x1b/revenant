# The CoreSpotlight classes AppIntents extends

The five rows this module adds to CoreSpotlight - `CSSearchableIndex.indexAppEntities(_:priority:)`,
`.deleteAppEntities(ofType:)`, `.deleteAppEntities(identifiedBy:ofType:)`,
`CSSearchableItem.init(appEntity:)` and `.init(appEntity:priority:)`, plus
`associateAppEntity(_:priority:)` on the item and its attribute set - are AppIntents' own extensions on
the three classes the CoreSpotlight backports carry (all three
`implemented`, with the store the port keeps under `/var/mobile/Library/Caches/org.revenant.corespotlight`
and the bridge to the release's own `SPSpotlightManager`).

## Why the classes need the port's headers

The SDK marks the three classes iOS 9, in the framework's own macros:

    CS_CLASS_AVAILABLE(10_13, 9_0)
    CS_TVOS_UNAVAILABLE
    @interface CSSearchableIndex : NSObject

The port's headers lower that mark to the port's release as they do for every declaration the registry
implements: the generator lowers it, and renders the copies. AppIntents probed CoreSpotlight through them, by the
runtime's port overlay (`REVENANT_SWIFT_PORT_HEADERS`, which no build sets since the port headers were removed). Without that overlay, measured: a Swift file naming
`CSSearchableIndex` at `armv7-apple-ios6.1.3` answers "'CSSearchableIndex' is only available in iOS 9.0
or newer".

## What the extensions do

`indexAppEntities` builds a `CSSearchableItem` per entity and hands them to `indexSearchableItems`,
which is the port's own store - the same call any other caller of CoreSpotlight makes, so an entity
indexed here is found by the port's search and not only by AppIntents. The entry's content type is
the entity type's name, its title and description are the entity's own display representation, and its
keywords are the entity's synonyms; the entity's identifier is written under
`appEntityIdentifier`, the key the framework's own search result reads.

`deleteAppEntities(ofType:)` and `deleteAppEntities(identifiedBy:ofType:)` read the journal the
backports keep - the same plists, over the same files - for the identifiers of one content type, and
hand them to `deleteSearchableItems`. With no CoreSpotlight backports there is no index and nothing
is removed, which is what a delete of an index that holds nothing does.

The two `NSUserActivity` rows (`widgetConfigurationIntent(of:)`, `appEntityIdentifier`) are behind
`-DREVENANT_APPINTENTS_PORT_HEADERS`, which the package sets when the runtime it builds against carries port
headers; none does since the runtime's `backports` config was removed, so the block is not compiled: `NSUserActivity` arrived in iOS 8 and the Foundation backports carry it, and
the runtime is what hands the port's headers over. They place on such a runtime; with a runtime built
without the backports there is no `NSUserActivity` on the release at all, and the rows read `missing`
rather than being declared against a class that is not there.
