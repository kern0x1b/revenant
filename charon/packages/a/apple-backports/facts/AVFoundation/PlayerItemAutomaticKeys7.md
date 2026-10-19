# AVPlayerItem: automatically loaded asset keys (iOS 7.0)

The three members that let an item say which asset keys it loads: `+playerItemWithAsset:automaticallyLoadedAssetKeys:`,
`-initWithAsset:automaticallyLoadedAssetKeys:` and the readonly property `automaticallyLoadedAssetKeys`. Built by
`AVFoundation/AVPlayerItemAutomaticKeys7.m` as a category on the release's own AVPlayerItem. Measured by
`tests/backports/host/avf-player-item-keys`, against Apple's members on the macOS host.

## What the release has, and what it does not

6.1.3's AVPlayerItem has `+playerItemWithAsset:` and `-initWithAsset:`, and its AVAsset has
`-loadValuesAsynchronouslyForKeys:completionHandler:` and `-statusOfValueForKey:error:`. So the keys can be loaded on this
release. What it does not have is a way for an item to remember which keys to load, so the three members are absent.

## What the host measured

Probe: `tests/backports/host/avf-player-item-keys/probe.m`, a one-second, 16x16 H.264 movie made by the host's own
AVAssetWriter; the row values below are the host's.

- **The factory and the initializer keep their keys**, in order, and the property reads them back
  (`duration,tracks`).
- **With no keys, the property reads the host's default list**: `duration` and
  `availableMediaCharacteristicsWithMediaSelectionOptions`. That is the macOS default. The iOS 7 default on the
  device was not measured, so the port answers the host's list and says so here.
- **An unknown key is kept without an error**: the item is made and reads the key back.
- **The keys load when the item goes into a player, not before.** On the host, an item that is only made leaves
  each key's status at Unknown (0). Put into an `AVPlayer`, the keys become Loaded (2) and the item becomes Ready
  (1) within 1.5 seconds. The plain factory's default keys load the same way.
- **Asking the asset about an unknown key raises**; the probe therefore reads only the item for that case.

## What the port does, and where it differs

The port loads the keys on the asset when the item is made (`-initWithAsset:automaticallyLoadedAssetKeys:`), and
does not wait for the item to go into a player. The release has no call the port can hook at that moment without
replacing its player methods, so the load starts at creation. The difference is visible in one place only: before
the item is in a player, the keys' status here is Loading or Loaded, where the host's is Unknown. The probe's
allowance covers exactly `A.duration.status` and `A.tracks.status` (the host 0, the port 1 or 2). Once the item is in
a player the two agree (rows D and E).

The port hands an unknown key to the asset's own loader at creation too. That did not raise: the port run completes
row C, and its table matches the host's for that row (the host's item keeps the key and is never asked about it).

## A finding about the test, which shaped it

Apple's own `-initWithAsset:` calls the keys initializer on the item it makes. A category that overrides
`-initWithAsset:automaticallyLoadedAssetKeys:` on AVPlayerItem, and calls `-initWithAsset:` as the port does, therefore
recurses without end on the host: a plain `[[AVPlayerItem alloc] initWithAsset:]` with the category linked overflows
the stack (measured, exit 139). On 6.1.3 the release's `-initWithAsset:` does not call this selector, because the
selector does not exist there, so the port's category is safe on the release. The host differential cannot override
the host's own class without the loop, so the probe's port run uses a stand-in class (`standin/`) that holds a real
AVPlayerItem made by Apple's initializer. The category is compiled onto the stand-in from a scratch copy of the port's
file (the class name changed, nothing else). The asset's key loading and the readbacks come from the port's code.

## Checks

- `run.sh`: 22 rows, 20 equal and 2 under the allowance; the owner lines show the host's members answered by the system
  and the port's by this executable.
- The planted control `AVPLAYERITEMKEYS_MUTANT=1` changes the default key list in the scratch copy: two rows change and
  the run is red.

## Caveats

- Host-measured, not device-measured. The default key list is the host's; the device's was not read.
- The port's keys load at creation, not at attachment (the allowance above).
- `playable` is not loaded by the port, so its status is 0 in both runs, which is what the probe checks.
