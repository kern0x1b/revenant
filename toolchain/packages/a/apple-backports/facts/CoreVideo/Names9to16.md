# Constant strings of CoreVideo that iOS 9 to 16 added

The twenty names this port carries, one object per release, and the value each one holds.

Every value was read out of a real CoreVideo and not from the name: two of the twenty spell
something the name does not say, and a guess would have got both wrong.

| constant | release | value | where the value was read |
| --- | --- | --- | --- |
| `kCVPixelBufferOpenGLESTextureCacheCompatibilityKey` | 9.0 | `OpenGLESTextureCacheCompatibility` | the iOS 9.0 armv7 cache, and the host |
| `kCVMetalTextureUsage` | 11.0 | `MetalTextureUsage` | the host |
| `kCVImageBufferAlphaChannelModeKey` | 13.0 | `AlphaChannelMode` | the host |
| `kCVImageBufferAlphaChannelMode_PremultipliedAlpha` | 13.0 | `PremultipliedAlpha` | the host |
| `kCVImageBufferAlphaChannelMode_StraightAlpha` | 13.0 | `StraightAlpha` | the host |
| `kCVMetalTextureStorageMode` | 13.0 | `MetalTextureStorageMode` | the host |
| `kCVPixelBufferProResRAWKey_BlackLevel` | 14.0 | `ProResRAW_BlackLevel` | the host |
| `kCVPixelBufferProResRAWKey_ColorMatrix` | 14.0 | `ProResRAW_ColorMatrix` | the host |
| `kCVPixelBufferProResRAWKey_GainFactor` | 14.0 | `ProResRAW_GainFactor` | the host |
| `kCVPixelBufferProResRAWKey_RecommendedCrop` | 14.0 | `ProResRAW_RecommendedCrop` | the host |
| `kCVPixelBufferProResRAWKey_SenselSitingOffsets` | 14.0 | `ProResRAW_SenselSitingOffsets` | the host |
| `kCVPixelBufferProResRAWKey_WhiteBalanceBlueFactor` | 14.0 | `ProResRAW_WhiteBalanceBlueFactor` | the host |
| `kCVPixelBufferProResRAWKey_WhiteBalanceCCT` | 14.0 | `ProResRAW_WhiteBalanceCCT` | the host |
| `kCVPixelBufferProResRAWKey_WhiteBalanceRedFactor` | 14.0 | `ProResRAW_WhiteBalanceRedFactor` | the host |
| `kCVPixelBufferProResRAWKey_WhiteLevel` | 14.0 | `ProResRAW_WhiteLevel` | the host |
| `kCVPixelBufferVersatileBayerKey_BayerPattern` | 14.0 | `ProResRAW_BayerPattern` | the host |
| `kCVImageBufferAmbientViewingEnvironmentKey` | 15.0 | `AmbientViewingEnvironment` | the host |
| `kCVImageBufferRegionOfInterestKey` | 15.0 | `RegionOfInterest` | the host |
| `kCVPixelBufferProResRAWKey_MetadataExtension` | 15.0 | `ProResRAW_MetadataExtension` | the host |
| `kCVPixelFormatContainsSenselArray` | 16.0 | `ContainsSenselArray` | the host |

## The two names whose value is not its own suffix

`kCVPixelBufferVersatileBayerKey_BayerPattern` is not `VersatileBayer_BayerPattern` and not
`BayerPattern`. The string the framework holds is `ProResRAW_BayerPattern`, read from the host's own
CoreVideo, and the two are independent measurements of the same name: the armv7 shared cache of iOS
9.0 through `tools/corpus/cache-value.lua` and the host through `dlsym`. The header calls the attachment a
"code indicating Bayer pattern (sensel arrangement)" whose value follows the ProRes RAW
`bayer_pattern` bitstream syntax element, so the framework reusing the ProRes RAW spelling for the
versatile Bayer format is what the code does, not what the name suggests.

`kCVPixelBufferOpenGLESTextureCacheCompatibilityKey` is `OpenGLESTextureCacheCompatibility` and not
`OpenGLESCompatibility`, which is the name of the sibling key the release itself carries from iOS 6.
Both sources agree on all 20 bytes.

## Where the values were read

The host is macOS 27.0 (26A428), and its CoreVideo exports all twenty, each symbol's address coming
from the export trie and the `__cfstring` stored there naming the text.
`kCVPixelBufferOpenGLESTextureCacheCompatibilityKey` is marked `API_UNAVAILABLE(macosx)` in the
header of iOS 16.4, so the value was read from a release that does carry it:

```
$ printf 'kCVPixelBufferOpenGLESTextureCacheCompatibilityKey\tp\tp\ts\n' > .agent-work/runs/cv9-symbols.tsv
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.charon/dyld/9.0/dyld_shared_cache_armv7 .agent-work/runs/cv9-symbols.tsv
```

The reader answers with the symbol's install, its address and the string its pointer names, which is
`OpenGLESTextureCacheCompatibility` (33 bytes) in CoreVideo's image of that cache.

## The releases carry none of them

Measured, not assumed. The name index of the port's own ladder
(`tools/cache-index/first-rung.lua`, over 50 held releases) answers, for each of the twenty, the
oldest held release that carries it: `9.0` for the OpenGLES key, `10.0.1` for
`kCVMetalTextureUsage`, and `16.0` for the other eighteen, because no release between 9.3.6 (the
last armv7 rung) and 16.0 is held and a 13.0, 14.0 or 15.0 name therefore first appears on the
arm64e rung. Asked directly of the two releases the port supports, through the export trie of
CoreVideo rather than through the index:

```
6.1.3 armv7: CoreVideo exports 204, and none of the twenty is among them
4.3   armv7: CoreVideo exports 178, and none of the twenty is among them
```

So an application that names any of them loads, and a key is never found in a dictionary a release
of this port makes, a notification is never posted under one, and a value handed to the release is
treated as the release treats any string it does not know.
