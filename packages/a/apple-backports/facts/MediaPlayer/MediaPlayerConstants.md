# The MediaPlayer constants the port carries

Thirty-two string constants, in twelve objects, one release each, because `release-split` refuses an
object whose symbols sit on two rungs of the ladder. The rungs are measured with
`tools/cache-index/first-rung.lua` over the 32 symbol names: one at 3.0, three at 7.0, one at 8.2, twelve
at 9.0, one at 9.1, three at 9.3, five at 10.0.1, one each at 10.2, 10.3, 11.0 and 12.0, and two at 16.0.
**`MPMediaPlaylistPropertyCloudGlobalID` first appears at 8.2**, where the corpus filed it under 9.0, and
the tool decides the ladder rather than the corpus.

The values are Apple's, read from the host's own `MediaPlayer` by `dlsym` and printed as text and bytes
by `tests/backports/host/mediaplayer-constants`. **They are not this symbol's name: 15 of the 32 hold
something else.** Ten of them are dotted `public.*` strings, `MPMediaPlaylistPropertySeedItems` holds
`seedItems`, `MPMediaPlaylistPropertyAuthorDisplayName` holds `externalVendorDisplayName`,
`MPMediaPlaylistPropertyDescriptionText` holds `descriptionInfo`, and
`MPNowPlayingInfoPropertyCurrentLanguageOptions` holds the **singular**
`MPNowPlayingInfoPropertyCurrentLanguageOption` — a one-character difference that a naming convention
would have got wrong. Foundation's own constants gave the same warning: 12 of 15 were not their names.

**Two of the 32 this Mac's own MediaPlayer does not have**, `MPVolumeViewWirelessRouteActiveDidChange
Notification` and `MPVolumeViewWirelessRoutesAvailableDidChangeNotification`. Their values are read out of
the armv7 cache of 7.0 by `tools/corpus/cache-value.lua`, which reads a 32-bit cache's pointers as 32 bits wide
(they carry no flags above an address, so there is nothing to unslide). The test prints which oracle judged which
name.

**iOS 6.1.3 exports none of the 32 MediaPlayer constants** — the MediaPlayer image of its armv7 cache,
extracted the same way, carries 0 of the 32 symbol names, `_MPErrorDomain` among them — so the port
carries every one of them.

A constant is **read, never called**. Nothing here touches `MPMediaLibrary`, `MPMediaQuery` or a library.