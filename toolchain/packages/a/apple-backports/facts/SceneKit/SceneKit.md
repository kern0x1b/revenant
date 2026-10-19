# SceneKit: the .scn archive format, measured against real Telegram assets

Source of the measurements below: `/Applications/Telegram.app/Contents/Resources/{gift,diamond,star2,coin,badge,business,lightspeed,star,swirl}.scn`,
the macOS Telegram client installed on the development machine — a static app
resource, not user data. Read with `plutil -p` and with Python's `plistlib`
(walking `$objects`/`$class`/`$classname` to trace which object references
which). Cross-checked against a real `SCNScene(url:)` load on macOS SceneKit
via a throwaway Swift script, which is a real, running Apple SceneKit acting
as a behavior oracle, not a guess.

**Retracted 2026-09-23: iOS-asset equivalence was assumed, and half of it is wrong.** Measured since: the iOS
Telegram 12.9.2 loads ten scenes (`submodules/PremiumUI/Resources/`, gzip): `star2`, `coin`, `gift2` and seven without geometry (`badge`, `emoji`, `tag`, `business`, `boost`, `lightspeed`, `swirl`). Decompressed, `star2`
and `coin` are byte for byte the macOS files above; `gift2` — what GiftAvatarComponent and PremiumDiamondComponent
load — matches neither `gift.scn` nor `diamond.scn`, which the iOS client does not load at all. What this file says
about `gift`/`diamond` is true of those macOS files and says nothing about `gift2`. `SCNView.md` has the inventory of
the ten iOS scenes.

## Fact: an archived color is an `NSColor` in its authoring color space — nested or in the graph

Two shapes, both measured on all four files (`gift`/`diamond`/`star2`/`coin`):

- `SCNLight.color`/`.shadowColor` and `SCNParticleSystem.particleColor`: an `NSMutableData`
  whose bytes are a complete, independent `NSKeyedArchiver` payload with an `NSColor` root.
- `SCNMaterialProperty.color` (every solid-color slot: 14 of `star2`'s 24 properties, and
  `SCNScene.background`/`environment`): the `NSColor` object sits **directly in the main
  object graph** (a UID straight to a `$classname: "NSColor"` object).

The `NSColor` object itself has the same keys in both: `NSColorSpace` (integer: 1 calibrated
RGB, 2 device RGB, 3 calibrated white, 4 device white), `NSComponents` (**raw bytes**, a
space-separated ASCII float list in the authoring space, alpha last), `NSRGB` or `NSWhite`
(raw NUL-terminated bytes, the same color converted to calibrated RGB/white), and
`NSCustomColorSpace` -> an `NSColorSpace` object with `NSICC` (the ICC profile) plus
`NSSpaceID`/`NSID`. In the graph shape `NSICC` is an `NSMutableData` object; in the nested
shape it is a bare plist `data` value.

**Retracted:** this section used to say `NSComponents` is a dictionary holding `NSRGB`/
`NSWhite` strings, and `CharonSCNArchivedColor` read it that way. It is raw bytes, and
`NSRGB`/`NSWhite` are sibling keys. The old reading could never have produced a color from
these files: no guest probe printed a color before 2026-09-23, so the error went unseen, and
every light/particle color sat at its class default.

Authoring spaces measured (103 `NSColor` objects in the four files): Display P3 (ICC, `para`
type 3 curves), sRGB IEC61966-2.1 Linear (ICC, gamma 1; every light color), sRGB (the HP
3144-byte ICC, 1024-entry `curv`), Generic Gray Gamma 2.2 (ICC, `curv`), and Generic Gray
with no ICC at all (`NSColorSpace` 3, alone or with `NSID` 2).

What real SceneKit exposes (macOS oracle,
`.agent-work/plan-and-analysis/color-oracle/oracle.swift` in the band worktree): the
`NSColor` in its authoring space, unconverted. `NSComponents` and `NSRGB` differ
(`star2` ambient: 0.4845 vs 0.4090), so reading `NSRGB` as if it were sRGB would be wrong.

Implementation: `CharonSCNArchivedColor` (mapped for `NSColor`) converts to sRGB, the only
meaning a spaceless `UIColor` on this platform has. It uses the profile's own `rXYZ`/`gXYZ`/
`bXYZ` matrix and `rTRC`/`gTRC`/`bTRC` (or `kTRC`) curves to reach PCS XYZ, then goes through
the inverse of the sRGB profile's D50 colorants and the IEC sRGB encoding, clamped to [0,1].
A calibrated white without a profile is Generic Gray, gamma 1.8: measured, `coin`'s
`NSWhite 0.3652207168` -> oracle sRGB 0.4406431317. Device RGB/white is taken as sRGB.
Calibrated RGB without a profile (Generic RGB) appears in no measured file and is refused,
so `nil`, as is a LUT-based profile. `CharonSCNArchivedColorSpace` (mapped for `NSColorSpace`)
carries only `NSICC`. `decodeColor:` maps both class names on whichever `NSKeyedUnarchiver`
holds the color: the caller's for the graph shape, a fresh inner one for the nested shape.
A colour that is not read (a refused space, a profile that does not convert, a catalog or
pattern colour, an empty or unreadable nested archive, an exception from the decode) leaves the
property at its default, and the log says so once, naming the key and the reason
(`SceneKit: the colour under <key> is not read, ...`); the scene still loads. In a material the
default is the slot's, as a new material holds it (diffuse white, emission black, roughness
grey); a property decoded on its own has nil. Measured on macOS SceneKit (macOS 27,
`.agent-work/runs/f1-oracle` of the band): a slot whose contents are nil is archived with no
`color`, `image` or `float` key and decodes to nil, so that shape stays nil here and only a
`color` key that is present and not read falls back. macOS itself never reads such a key as
nothing: AppKit decodes every `NSColor` shape tried (an unknown colour space number, no
components, an unknown catalog name) to some colour object, and one SceneKit cannot convert
(the last two) is drawn black. This port holds no `NSColor`, so it keeps the slot's default
and says so; a `color` key holding an object that is not a colour raises inside macOS SceneKit
(`-scn_C3DColorIgnoringColorSpace:success:` unrecognised) and is refused here instead.

Checked against the oracle's `usingColorSpace(.sRGB)` components, host prototype
(`color-oracle/proto.py`): 102 of 103 colors match to 1.2e-4, the worst being Display P3
white (s15Fixed16 quantisation of the P3 colorants). The 103rd is the `groundColor`
parameter of `diamond`'s procedural sky (`SCNScene.environment` -> `MDLSkyCubeTexture`),
which SceneKit never exposes as a color.

## Fact: image/file content is `{"path": "<name>"}`, exposed as the bare filename string

`SCNMaterialProperty.contents` and `SCNParticleSystem.particleImage`, when
they hold a file reference, do not carry image bytes. They are archived as
`{"path": "<filename>"}`, e.g. `coin.scn`'s three diffuse textures decode to
the literal strings `"lighterTexture.jpg"`, `"darkerTexture.jpg"`,
`"texture.jpg"`, and `gift.scn`'s `particleImage` decodes to `"particles.png"`.
In every case the named file is a flat sibling of the `.scn` in
`Contents/Resources/` — confirmed by `find`, not assumed.

**The public property's exposed value is the bare filename string, not a
resolved URL** — measured directly against real SceneKit (a throwaway Swift
script printing `type(of:)`/`String(describing:)` on `material.diffuse.contents`
and every `particleSystem.particleImage` in `gift.scn`/`star2.scn`): both come
back `__NSCFString` / `"particles.png"`, `"texture.jpg"`, unresolved, no scene
directory prefix. An early draft of this port resolved the reference into an
`NSURL` relative to the scene's source URL instead (plausible-looking, and it
is exactly what a renderer would eventually need to actually load the file) —
that draft shipped once already (`particleImage`, with `gift`/`diamond`) before
being caught by this same direct-Swift-check technique and corrected in both
places together. `CharonSCNCoding.decodeFileReferenceName:forKey:` now returns
the bare `NSString` for both properties; nothing between here and the archive
resolves it against the scene's source.

The scene-source stack (`+[CharonSCNCoding pushSourceURL:]`/`popSourceURL`/
`currentSourceURL`, pushed by `+[SCNScene sceneWithURL:options:error:]` around
the decode) is left in place, unused by any decoder now — real, harmless,
already-wired infrastructure for whenever a renderer actually needs to load
the named file relative to the scene, at which point resolving it is that
renderer's job, not the property getter's. This mirrors the real mechanism
`loadCompressedScene` already depends on: Telegram decompresses to a temp
directory first specifically so a relative lookup has something to resolve
against.

## Two "вероятно" from the previous turn, closed by tracing referrers, not by reading types

- **`SCNPlane`** in `gift.scn`: exactly one instance, referenced only by
  `SCNParticleSystem.emitterShape` (never by any node's `.geometry`). It is
  a shape for particle emission math, not a drawn surface. Its own
  `.materials` array holds one `SCNMaterial` that has never had any of
  `diffuse`/`ambient`/`specular`/etc. touched (none of those keys appear in
  its archived dictionary) — every `SCNGeometry` carries a materials array
  by construction, this one is inert.
- **`SCNMaterial`/`SCNMaterialProperty`** in `gift.scn`: the nine
  `SCNMaterialProperty` instances belong to `SCNLight.gobo`/
  `.probeEnvironment` (five different lights) and `SCNScene.background`/
  `.environment` — not to any visible mesh (there is none in this file) and
  not to particles either (particle appearance goes through
  `particleImage`/`particleColor` directly, not through a `SCNMaterial`).
  None of the nine carry a `contents` key at all. Consequence: `gift` and
  `diamond` need zero texture-decoding code for materials — only property
  bags that decode to their defaults.

## Divergence table: API name vs. archive key name

The single most dangerous class of bug here: property exists, decoder
doesn't recognize the archive key, value silently stays at its default,
nothing crashes, the scene renders looking wrong. Keep this list as the one
place that protects against it — do not scatter individual notes in code
comments.

| Class | Public API name | Archive key | Effect if missed |
| --- | --- | --- | --- |
| `SCNNode` (`SCNParticleSystemSupport` category) | `particleSystems` (array) | `particleSystem` (**singular**, one object — plural `particleSystems` array key also exists and is additionally checked) | a node's particle emitter never attaches; nothing emits |
| `SCNCamera` | `fieldOfView` | `yFov` (falls back to `fov`) | camera renders at whatever default FOV we pick instead of the authored one — wrong framing |
| `SCNLight` | `categoryBitMask` | `lightCategoryBitMask` | light/geometry category masking silently doesn't match; harmless unless the scene relies on masks to exclude a light from some geometry — not the case in `gift`/`diamond`/`star2`/`coin`, all lights hit everything |
| `SCNLight` | `automaticallyAdjustsShadowProjection` | `autoShadowProjection` | not implemented this turn (shadow-quality tier, see skip list) — recorded here so whoever adds it does not re-derive the divergence |
| `SCNMaterialProperty` | `contents` | `image` (file-backed) / `color` (solid-fill) / `float` (scalar) — never `contents` itself | measured on `star2.scn`'s real diffuse property (object `#556`): the archive has no `contents` key at all on any of its 24 `SCNMaterialProperty` instances; the union of keys actually used is `image`/`color`/`float`/`borderColor`/... A decoder reading `contents` silently leaves every material's every slot at its default — nothing crashes, the mesh loses its texture |

A key that holds a list (`particleSystem`, `particleSystems`, `childNodes`, `materials`, each
geometry-source semantic, `elements`) may hold a single object instead, and a decode that allows
both `NSArray` and the class lets either through. `+[CharonSCNCoding decodeArrayOfClass:coder:forKey:]`
is the one place that reads such a key: a single object becomes a one-element list, and an element
of another class is left out with a log line naming the key. Before it, a single particle system
reached `.count` and died on an unrecognized selector (`tests/backports/device/scenekit-decode.m`).
Only a secure decode (SCNScene's loader) holds the value to those two classes; an application's own
unarchiver without secure coding hands back whatever the key holds, so a value that is neither the
class nor an array is left out the same way, with the same log line, instead of being enumerated.

## Skip list: keys read from the archive but not decoded, by class, with visual weight

Not decoding these is a real, named cut — not an oversight. Split by
whether the owner is the *authoring tool* (Xcode's Scene Editor: editor
state, bookkeeping) or the *renderer* (would visibly change the picture if
wired up).

**`SCNLight`** (measured on `gift.scn`'s five light instances: types
`ambient`, `omni`×2, `area`, `directional`×2):
- editor-only, no visual effect if skipped: `baked`, `version`,
  `shouldBakeIndirectLighting`, `shouldBakeDirectLighting`,
  `usesDeferredShadows`, `usesModulatedMode`, `shadowSampleCount2`,
  `scncolor`/`scnShadowColor` (private float4 duplicates of `color`/
  `shadowColor`, redundant with the nested-archive path already decoded).
- shadow-quality tier, real visual effect but only on shadow *softness/cost*,
  not on whether a shadow exists (`castsShadow`/`shadowColor`/`shadowRadius`
  are decoded): `shadowMapSize`, `shadowSampleCount`, `shadowBias`,
  `shadowCascadeCount`, `shadowCascadeSplittingFactor`, `orthographicScale`,
  `maximumShadowDistance`, `forcesBackFaceCasters`,
  `sampleDistributedShadowMaps`, `automaticallyAdjustsShadowProjection`
  (archived `autoShadowProjection`, see divergence table).
- area-light geometry, real visual effect, skipped because `gift`/`diamond`
  use `area` type but our decoder does not yet read it:
  `areaExtentsX`/`Y`/`Z` (public API exposes these as one `simd_float3
  areaExtents` — the archive splits them into three scalars, a second,
  smaller divergence worth folding into the table above once implemented),
  `areaPolygonVertices`, `drawsArea`, `doubleSided`, `areaType`. An area
  light without these falls back to a point-light approximation — visibly
  softer/harder than authored.
- probe/IES tier, not used by any of the four target files per the earlier
  per-file class survey (no `SCNLightTypeProbe`/`SCNLightTypeIES` instance
  found): `IESProfileURL`, `probeType`, `probeUpdateType`, `probeExtents`,
  `probeOffset`, `parallaxCorrectionEnabled`, `parallaxExtentsFactor`,
  `parallaxCenterOffset`, `sphericalHarmonicsCoefficients` (also `readonly`
  — computed, never authored, so there is nothing to decode regardless).

**`SCNCamera`** (measured on `gift.scn`'s one camera): decoded
`fieldOfView`, `zNear`, `zFar`, `usesOrthographicProjection`,
`orthographicScale`, `automaticallyAdjustsZRange`. Everything else in the
archive is post-processing the real device never had cause to reproduce
faithfully and that materially changes the look if half-wired: `wantsHDR`,
`bloomIntensity`/`bloomThreshold`/`bloomIteration`/`bloomIterationSpread`/
`bloomBlurRadius`, `wantsDepthOfField`/`focusDistance`/
`focalBlurSampleCount`/`fStop`/`apertureBladeCount`(archived
`bladeCount`)/`sensorHeight`(archived `sensorSize`), `motionBlurIntensity`,
`screenSpaceAmbientOcclusion*` (four keys), `wantsExposureAdaptation` and
its seven `exposureAdaptation*`/`minimumExposure`/`maximumExposure`/
`exposureOffset` companions, `grainIntensity`/`grainScale`/`grainIsColored`,
`colorFringeIntensity`/`colorFringeStrength`, `vignettingIntensity`/
`vignettingPower`, `contrast`/`saturation`/`whitePoint`/`averageGray`,
`whiteBalanceTemperature`/`whiteBalanceTint`, `focalLength`,
`projectionDirection`, `fillMode`, `categoryBitMask`. All of these are real
SceneKit render features (bloom, DOF, SSAO, exposure, film grain, vignette,
color grading) — skipping them means the port's picture is flatter and
sharper than Apple's own renderer would produce, every one of them a
legitimate deferred-implement, not a "doesn't matter."

**`SCNParticleSystem`**: decoded the emission/velocity/lifespan/size/color/
image/shape/blend/sort/lighting/gravity-coupling surface (see
`SCNParticleSystem.m`). Skipped, all with real per-particle visual effect:
`seed` (deterministic-vs-random look between runs), `particleMass`/
`particleMassVariation`, `particleBounce`/`particleBounceVariation`,
`particleFriction`/`particleFrictionVariation`, `particleCharge`/
`particleChargeVariation` (all four feed physics-field force response —
`gift.scn`'s particles are `affectedByPhysicsFields: true` against a
`SCNPhysicsRadialGravityField`, so an unset `particleMass` defaulting to 1
is an approximation, not a no-op), `particleIntensity`/
`particleIntensityVariation`, `particleDiesOnCollision`/
`physicsCollisionsEnabled`/`softParticlesEnabled`/`blackPassEnabled`,
`isLocal`, `birthLocation`, `renderingMode`, `writesToDepthBuffer`,
`fixedTimeStep`, `dampingFactor`, the `imageSequence*` family (sprite-sheet
animation — `gift.scn`'s `particleImage` decode showed a plain
`{"path":...}`, not an image-sequence configuration, so this tier is
confirmed inert for this file, not merely skipped), `birthDirection`
(archived as raw bytes the same shape as `emittingDirection`, not yet
wired).

**`SCNPhysicsField`**: decoded `strength`, `falloffExponent`,
`minimumDistance`, `active`, `exclusive`, `usesEllipsoidalExtent`, `scope`,
`categoryBitMask`. Skipped: `halfExtent`, `offset`, `direction` (all three
are `SCNVector3`, likely the same raw-bytes shape as node transforms —
not yet measured on the field object itself, only inferred from the header;
flagged here rather than assumed and left silently wrong).

**`SCNMaterial`**: decoded `name`, the full readonly `SCNMaterialProperty`
slot set (`diffuse`/`ambient`/`specular`/`normal`/`reflective`/`emission`/
`transparent`/`multiply`/`displacement`/`ambientOcclusion`/
`selfIllumination`/`metalness`/`roughness`), `lightingModelName`,
`doubleSided`, `transparency`, `shininess`, `blendMode`. Skipped, measured
present on `gift.scn`'s inert plane material and real on `coin.scn`'s PBR
meshes: `fresnelExponent`, `indexOfRefraction`, `transparencyMode`,
`cullMode`, `litPerPixel`, `fillMode`, `locksAmbientWithDiffuse`,
`avoidsOverLighting`, `colorBufferWriteMask`, `writesToDepthBuffer`,
`readsFromDepthBuffer`, `selfIlluminationOcclusion`. All real rendering
knobs; none block a mesh from appearing, all can make it look subtly wrong
(culling, depth test, transparency compositing mode).

## Visual-accuracy deficit list — first entry: `gift.scn`'s main light is an area light

This is the running list `check_releases`/the skip list above promised: not
"what's missing" but "what will look wrong, and why." First concrete entry,
not a hypothetical one.

`gift.scn`'s `"frontal"` light — its main light, per the macOS SceneKit
oracle dump — has `type = area`. The `SCNLightTypeArea` constant itself is
carried honestly: `SCNLight.type` reads the real archived string and answers
`"area"` truthfully. But the *behavior* an area light implies — a light with
physical extent, producing a soft-edged shadow and a falloff shaped by that
extent and by `areaPolygonVertices`/`drawsArea`, not the sharp single-point
falloff of an omni or directional light — is not implemented by this port's
renderer. `areaExtentsX/Y/Z`, `areaPolygonVertices` and `drawsArea` are on
the skip list above, decode-but-unused.

Net effect: `gift.scn` decodes completely and correctly — the type is read,
the value returned, nothing crashes or lies about what kind of light it is —
but the rendered scene's main light will look like whatever this port's
point/directional fallback produces, not the soft area-light SceneKit's own
renderer would draw. When the picture looks wrong, this is where to look
first: not a decode bug, a renderer gap, on the very first tier.

This is not a reason to withhold the constant. An application that asks
`SCNLight.type` and gets the true answer behaves correctly; one that gets a
false answer does not. The surface is carried honestly; the renderer's gap
is named honestly beside it, not hidden behind a truthful-looking property.

### Deficit entries added 2026-09-23 by the color oracle

- `SCNScene.background`, `.lightingEnvironment` (archive key `environment`) and `.fogColor`
  are not carried: `SCNScene` has neither the properties nor the keys. All four files set
  `background` to a transparent color (alpha 0) and `fogColor` to Display P3 white; the
  environment is the same transparent color, except in `diamond`, where it is a procedural
  sky (`MDLSkyCubeTexture` built from an `NSDictionary` of sky parameters under
  `SCNMaterialProperty.image`). No demand row names these properties yet
  (`coordination/corpus/*.tsv`, grep), so they are recorded here and not built.
- `clearCoat`/`clearCoatRoughness`/`clearCoatNormal` (iOS 13 API) are set on every PBR
  material in `star2`/`coin` (`flecks.jpg` normal, 0.3-0.45 intensity). `SCNMaterial` in this
  port does not carry them, so the clear-coat sparkle is missing from the picture.

## `xmake f -y` without `-c` after an edit can silently not re-evaluate the package

`-y` alone, run again after changing an already-configured package's sources,
can hand back a cached "already satisfied" decision without re-checking the
package at all — a config log a few dozen lines long with no mention of the
package's name anywhere in it is the sign, not a green exit code by itself.
`-c` (full reconfigure) is what actually forces the package requirement to
be re-evaluated. Measured on this port: a config run right after splitting
`SCNLightTypeProbe` out of `SCNLightConstants10.m` produced a 46-line log
with zero mentions of `apple-backports` and exit 0 — looked done, proved
nothing. The same command with `-c` produced a real several-thousand-line
band rebuild and a freshly digested install path.

## `tools/release-split.lua` — the release-splitting check the build gate does not fully cover

`band()`/`band_ranges()` in `modules/apple/backports.lua` catch a symbol
whose introduced release does not match its object file's other symbols only
against the one release each already-existing band boundary happens to
check against — a registry's declared `introduced` version gets rounded up
to the nearest of those boundaries first. Two symbols declared for the same
rounded-up boundary can share a `.m`, link clean, and still be a full release
apart in truth. Measured on this port: `SCNLightTypeIES` and
`SCNLightTypeProbe` were both declared `introduced: "10.0"` in one object
file; `check_releases` and `band()` both accepted it and
`libSceneKitBackports.dylib` linked and installed with no complaint.
`tools/release-split.lua`, walking the real `~/.charon/dyld/*` cache ladder
symbol by symbol instead of by band boundary, found `SCNLightTypeProbe`
already exporting at 9.0 — the registry entry was wrong by a full release,
underneath a green gate. Run it before a band build, not instead of one: see
the script's own header for what it does and does not cover.

The opposite mistake happened with a string search. `SCNGeometrySourceSemanticTangent`
was carried as 9.3.6 because the literal `kGeometrySourceSemanticTangent`
first appears in 9.3.6's cache, but a string is not the export: measured
through `apple.dyld`'s export table (2026-09-24), `_SCNGeometrySourceSemanticTangent`
is absent at 9.0/9.2.1/9.3/9.3.5/9.3.6 and present at 10.0.1, with
`_SCNGeometrySourceSemanticNormal` and `_OBJC_CLASS_$_SCNPhysicsWorld` found
at 8.0 as controls. The entry is now 10.0.1 (`registry/SceneKit/ios10.json`).
A release is read from the exported symbol, not from a string the cache holds.

## `SCNParticlePropertyController.animation` is not a `CAAnimation` reference in the archive

Measured on `gift.scn`, confirmed by the real guest decode failing loudly before this was
fixed: the archive's `animation` key under a `SCNParticlePropertyController` is not a
`CAAnimation` object reference at all. It is a generic, engine-agnostic dictionary --
`{"class": "animation", "animation": {"keyframe": {...16 key/value pairs...}}}` -- that
Xcode's Scene Editor emits instead of relying on `CAAnimation`'s own `NSCoding`. Reconstructing
a real `CAKeyframeAnimation` from that dictionary shape is not implemented; `initWithCoder:`
now accepts either a real `CAAnimation` (kept) or a dictionary (silently kept nil, not
crashed). Effect: `SCNParticlePropertyController.animation` is `nil` for every controller
gift.scn/diamond.scn carry, so whichever particle property they meant to vary over life
does not vary -- named here as visual-accuracy deficit list item two, alongside the area
light. Do not extend `initWithCoder:` for this key from the four fields seen in one
`gift.scn` instance without re-checking a wider sample first (the dictionary format may
carry more animation kinds -- basic, spring -- than keyframe).

## `SCNPhysicsRadialGravityField` has no public header at all

Unlike every other class in this facts file, `SCNPhysicsRadialGravityField`
is not declared anywhere in `SceneKit.framework/Headers/*.h` in SDK 16.4.
Apple exposes it only indirectly, through `+[SCNPhysicsField
radialGravityField]`, which returns a plain `SCNPhysicsField *`-typed
pointer to a private concrete subclass — the same pattern the archive
depends on by naming the class directly (`$classname: "SCNPhysicsRadialGravityField"`,
confirmed by `plutil`/`plistlib` on `gift.scn`, `diamond.scn`, `star2.scn`,
`coin.scn`). Our port declares this class itself, in `CharonSCN.h`, since
there is no Apple header to import it from. The same will likely be true
for `SCNPhysicsVortexField` (needed only by `swirl.scn`, outside the current
four-file scope) and any other field subclass reached later.

## `gift.scn` decodes correctly on a real armv7 guest — measured, not just built

`SCNScene`, `SCNNode`, `SCNGeometry`, `SCNPlane`, `SCNLight`, `SCNCamera`,
`SCNMaterial`, `SCNMaterialProperty`, `SCNParticleSystem`,
`SCNParticlePropertyController`, `SCNPhysicsField`,
`SCNPhysicsRadialGravityField`, the `NSValue(SceneKitAdditions)` category,
and the shared `CharonSCNCoding` helper — the complete class set `gift.scn`
and `diamond.scn` need per the per-file class survey (`gift`/`diamond` share
an identical `$classname` set; neither uses `SCNGeometrySource`/
`SCNGeometryElement`, which are `star2`/`coin`-only).

A probe (`.agent-work/plan-and-analysis/gift-probe/`, scratch, not committed)
embeds the real `gift.scn` bytes, decodes them through the actual
`SCNScene sceneWithURL:options:error:` entry point on the emulated `iPhone4,1
6.1.3` armv7 guest, and printf/fflush's the node tree. Result: `pass`,
`failures=0`, tree matches the real macOS SceneKit oracle node-for-node,
including child order (`particles → particles 3 → particles 4 → particles 2`,
not ascending — could not reproduce by coincidence).

Getting there cost five real, guest-caught decode failures, each fixed before
moving on, none described as a finding without a fix:

1. `SCNNode`'s `particleSystem` key (singular) decodes to an `NSArray`, not a
   bare `SCNParticleSystem` — `NSKeyedUnarchiver` named the key, the expected
   class and the real one directly.
2. `SCNPlane` overrode `-initWithCoder:` without redeclaring
   `+supportsSecureCoding`, which Foundation refuses even though the
   superclass already returns `YES` for it.
3. `SCNParticlePropertyController.animation` is not a `CAAnimation` reference
   in the archive at all — Xcode's Scene Editor serializes it as a generic
   `{"class": "animation", "animation": {"keyframe": {...}}}` dictionary.
   Reconstructing a real animation from that shape is not implemented;
   `initWithCoder:` now keeps it `nil` rather than crash — visual-accuracy
   deficit list item two.
4. `decodeBoolForKey:` throws when the archive stores the property as a plain
   integer instead of a boolean-tagged plist value — measured on
   `castsShadow` (archived as `0`, an integer).
5. The archive does **not** encode BOOL-shaped properties uniformly: `hidden`
   really is a boolean-tagged value where `castsShadow` is an integer, in the
   same file. A blanket switch to `decodeIntegerForKey:` (item 4's first fix)
   broke `hidden` immediately — a second, separate guest-caught failure from
   generalizing off one measured sample instead of re-checking. Fixed with a
   `CharonSCNCoding.decodeBool:forKey:default:` that tries `decodeBoolForKey:`
   first and falls back to `decodeIntegerForKey:` on exception, rather than
   assuming either encoding.
   Probing by exception stays, since `NSKeyedUnarchiver` answers no question
   about a value's stored type; a flag that is neither (both decodes raise)
   keeps its default and the log says so, naming the key
   (`tests/backports/device/scenekit-decode.m`).

**Honest remainder on the diff itself.** Every printed property whose value
differs from its class's init default (`particleLifeSpan=2` vs default `1`,
`particleVelocity=1.65` vs default `0`, five `SCNLight.type` strings across
five nodes including `"area"`, which no single default could produce) is
proven read from the archive — the value itself is the evidence. Three
properties instead print a value equal to their default:
`SCNParticleSystem.speedFactor` (`1`), `.stretchFactor` (`0`), and
`SCNCamera.fieldOfView` (`60`). For these three, the raw archive was
independently confirmed (via `plistlib`, not the probe) to carry the key
with that same value — `speedFactor: 1.0`, `stretchFactor: 0.0`,
`fov`/`yFov: 60.0` are genuinely present in the object dictionaries. That
proves the key exists in the file; it does not prove the decoder read it
rather than silently falling through to the same-valued default. Closing
that gap needs a value that differs from default on one of these three
specific keys, which `gift.scn` does not happen to provide. Do not spend a
dedicated run chasing it — the cost exceeds the value here.

**`diamond.scn` closed one of the three for free, the same run that was
already planned for the next tier.** `speedFactor` prints `0.85` on four of
its seven particle systems and `0.8502` on the fifth
(`particles_center`) — both away from the init default of `1`, and
distinguishable from each other, which no shared default could produce.
`speedFactor` is now proven read, the same way `particleLifeSpan`/
`particleVelocity`/`SCNLight.type` already were on `gift.scn`. `stretchFactor`
(`0` on all seven systems here too) and `SCNCamera.fieldOfView` (`60`) are
still open — check for them on `star2`/`coin`, whose PBR materials and real
meshes are more likely to carry a non-default value, rather than re-deriving
this paragraph or spending a dedicated run.

## `star2.scn` decodes correctly on a real armv7 guest, node-for-node against a macOS oracle

First real mesh in this port: `SCNGeometry`/`SCNGeometrySource`/`SCNGeometryElement`,
exercised end to end. Oracle: a throwaway Swift script running real Apple SceneKit
(`SCNScene(url:)`) against `/Applications/Telegram.app/Contents/Resources/star2.scn`,
recorded *before* the guest run, not fitted after. Guest: `.agent-work/plan-and-analysis/
gift-probe/star2_probe.m`, embedding the real file bytes, decoding through the actual
`SCNScene sceneWithURL:options:error:` on the emulated `iPhone4,1 6.1.3`.

Result: `pass`, `failures=0`, every one of 14 root children matches the oracle in order,
name, and every printed property — including the single mesh (`star` node):
`sources=3` (`kGeometrySourceSemanticVertex`/`Normal`/`Texcoord`, each
`vectorCount=1078 componentsPerVector=3-or-2 bytesPerComponent=4 stride=12-or-8 offset=0
dataLength=12936-or-8624`, exact), `elements=1` (`primitiveType=4` [Polygon]
`primitiveCount=777 bytesPerIndex=2 dataLength=7554`, exact), `lightingModel=
SCNLightingModelPhysicallyBased`, `diffuseContents=texture.jpg` (exact, see below).
Seven particle systems' `speedFactor`/`stretchFactor`/`lifeSpan`/`velocity` all matched
too, `speedFactor` again proving read (`0.85`/`0.8502` split, same pattern as `diamond.scn`).

**One real divergence found and fixed by this run, not by inspection first.** The first
guest run (before the fix below) decoded everything above identically except
`diffuseContents=(none)` where the oracle had `texture.jpg` — `SCNMaterialProperty.contents`
was nil. Traced with `plutil`/`plistlib` on the raw archive (not guessed): the archive's 24
`SCNMaterialProperty` instances carry no `contents` key anywhere; the real key is `image`
(file-backed, `{"path": "texture.jpg"}`, same shape as `particleImage`), `color` (solid-fill),
or `float` (scalar) depending on `propertyType`. Fixed in `SCNMaterialProperty.m` to read
`image`; re-ran the guest, `diffuseContents=texture.jpg` now matches the oracle exactly.
Divergence recorded in the table above.

**A second, independent finding from the same probe — and this one turned out to affect
already-merged code too, fixed the same turn.** The fix's first draft reused
`CharonSCNCoding.decodePathContents:`, which resolves a file reference to an `NSURL`
relative to the scene's source (the same helper `particleImage` already used, merged with
`gift`/`diamond`). A direct Swift test against real SceneKit
(`material.diffuse.contents`, printed via `String(describing:)`) showed the real property
holds the **bare filename string** `"texture.jpg"`, not a resolved URL — interpolating an
`NSURL` with a base prints `"texture.jpg -- file:///path/to/star2.scn"` (verified by
constructing one directly), which is not what real SceneKit returns. The same check run
against `gift.scn`'s `particleImage` (four particle systems, all resolving `"particles.png"`)
confirmed real SceneKit returns `__NSCFString`/`"particles.png"` there too — not the
`NSURL` this port had been building. Both call sites now share one helper,
`CharonSCNCoding.decodeFileReferenceName:forKey:`, which returns the bare archived
`NSString` and does not touch the scene-source stack at all. Re-ran all three probes
(`gift`/`diamond`/`star2`) on the armv7 guest after the fix: all three still `pass`,
`failures=0`, and `image=`/`diffuseContents=` now print the bare filename
(`particles.png`/`coin_anim.png`/`texture.jpg`) matching real SceneKit's exposed type, not
just its filename. `decodePathContents:` (the wrong, URL-building helper) is gone; the
scene-source push/pop stack in `SCNScene.m` is left in place, unused by any decoder now —
real infrastructure for whenever a renderer needs to actually load the named file, not a
property-getter concern.

**Closed 2026-09-23 (was "still open, unwired"):** the `color` slots (14 of `star2.scn`'s 24
properties hold an `NSColor` directly in the graph) are now decoded, and so are the `float`
slots (`metalness`/`roughness` scalars; oracle type `NSNumber`, e.g. `0.45`). See "an archived
color is an `NSColor` in its authoring color space" above, and the guest measurement in
"Colors on the guest" below.

## `coin.scn` decodes correctly on a real armv7 guest, five meshes, three textures, a real `SCNPhysicsWorld` — first try, zero new bugs

`coin.scn` is the last of the four target files and the heaviest: `star` is a group node
(no geometry of its own) with five real mesh children — `Affiliate`, `Plane`, `Business`,
`Inner`, `Outer` — three of which (`Affiliate`/`Plane`/`Business`) share `lighterTexture.jpg`,
one (`Inner`) uses `darkerTexture.jpg`, one (`Outer`) uses `texture.jpg`; two of the five
(`Affiliate`, `Business`) carry **two** `SCNGeometryElement`s each, not one — a tiny
`primitiveType=2` (Line, 3 primitives, 12 bytes) alongside the real `primitiveType=0`
(Triangles) element, both read and re-encoded faithfully, not merged or dropped. Oracle: the
same throwaway-Swift-against-real-SceneKit method as `star2`, recorded before the guest run.

Guest (`.agent-work/plan-and-analysis/gift-probe/coin_probe.m`, same embed-real-bytes-and-
decode-through-`SCNScene`-on-the-emulated-`iPhone4,1 6.1.3` method): `pass`, `failures=0`,
**every one of the 14 root children and all five mesh children matched the oracle exactly on
the first guest run** — no second bug like `star2`'s `image`-key miss. Every `vectorCount`/
`dataLength`/`primitiveCount`/`primitiveType`/`diffuseContents` for all five meshes, both
two-element geometries' Line-then-Triangles pair, and all three texture names matched
byte-for-byte against the numbers measured directly off the raw archive beforehand.

**`SCNPhysicsWorld` is a new class this turn, absent from this port entirely before now** —
`SceneKit.framework` never carried a `SCNPhysicsWorld` symbol on iOS 6 through 7.1.2
(`_OBJC_CLASS_$_SCNPhysicsWorld` first exports at 8.0, same release-ladder measurement
method as every other class here), and neither `gift.scn`/`diamond.scn`/`star2.scn` reach it
(no physics-configured scene until `coin`). `SCNScene`'s archive key is literally
`physicsWorld` (no divergence, matches the public property name) referencing a nested
`SCNPhysicsWorld` object with `gravity`/`speed`/`timeStep` archived under their own property
names too — plus an archive-only `scale` key with no public property to carry it to (not
decoded, matches the same "editor/private key" pattern already seen on `SCNLight`) and a
`scene` key that is a back-reference to the owning `SCNScene`, not a settable property (not
decoded either, would be a retain cycle if it were). `coin.scn`'s authored `gravity=(0, 1.75,
0)` is **not** the class default (`(0, -9.8, 0)`, real SceneKit's own documented default) —
proof the value is read, not coincidentally correct — and the guest printed the exact same
three numbers as the oracle on the very first run. `addBehavior:`/`removeBehavior:`/
`removeAllBehaviors`/`allBehaviors` are real array management (`coin.scn` attaches none, so
untested by this file, but not a stub); `rayTestWithSegment...`/two `contactTest...`
variants/`convexSweepTest...` return an honest empty array and `updateCollisionPairs` is a
genuine no-op — there is no `SCNPhysicsBody` anywhere in this port, so "no bodies, no
contacts" is the true answer for this scene, not a placeholder pretending to work.

**Nothing is simulated, so the class is `inert`, not `implemented`** (review of 2026-09-23,
item 4). With no body carried there is nothing for `gravity`, `speed`, `timeStep`, a behavior or
`contactDelegate` to act on: they are kept and read back and never act. The first time an
application sets one of them or adds a behavior, the log says so once (`SCNPhysicsWorld: nothing
is simulated on this port; ...`); values read from an archive say nothing, since the application
did not ask for them. `tests/backports/device/scenekit-decode.m` checks the decode, the read-back,
the one log line over several sets and a ray test that hits nothing.

## Colors on the guest: every light, shadow, particle and material color matches the oracle

Measured 2026-09-23 on the armv7 guest (`xmake emulate -d iPhone4,1 -r 6.1.3`, 10B329), through
the real `+[SCNScene sceneWithURL:options:error:]`, all four files in one probe
(`color_probe.m` in the band worktree's `.agent-work/plan-and-analysis/gift-probe/`), compared
field by field with the macOS oracle (`color-oracle/compare.py`): 213 values checked (116
colors, 85 numbers: each slot's `intensity` plus the `float` slots, 12 file names), 0
mismatches, worst color component error 1.2e-4. The four node-tree probes still print trees
identical to their earlier green runs.

The first guest run of the new color code matched every material slot but none of the nested
colors: every light, shadow and particle color stayed at its class default. Chased down, not
guessed:

- `decodeColor:` on the same nested bytes, outside a scene decode, returned the right color
  (0.803784, oracle 0.8037840724).
- Inside a scene decode, the outer `decodeObjectOfClasses:` returned an `NSConcreteMutableData`
  of **length 0**. A `SCNLight` subclass substituted by `setClass:forClassName:` measured it
  directly on a plain unarchiver.
- The difference is the key. `SCNKeyedArchiver` writes `NSMutableData` as `{NS.bytes: ...}`
  (12 to 22 per file, every one a nested color or the sky parameters); current Foundation
  writes `{NS.data: ...}`. A host-built `NS.data` archive decoded in full on the same guest,
  and the `NS.bytes` form came back empty through a plain `NSKeyedUnarchiver`.
- Through an `NSKeyedUnarchiver` *subclass*, or with `decodeObjectOfClasses:forKey:` swizzled,
  the same `NS.bytes` object came back whole (1026 bytes). Mechanism not identified. Debug
  interception of the unarchiver hides this failure, so do not trust an instrumented run for it.

Fix: `CharonSCNArchivedData`, an `NSMutableData` subclass mapped for `NSMutableData` on the
unarchiver `decodeColor:` is handed, reads `NS.bytes` or `NS.data` itself.

## Class defaults, from macOS SceneKit's new objects

What a new object answers is taken from macOS SceneKit, not from the documentation or from memory: the same
cases file, `tests/backports/device/scenekit-defaults-cases.m`, reads every property the port carries on a new
`SCNLight`, `SCNCamera`, `SCNParticleSystem`, `SCNMaterial` (each slot's contents and intensity),
`SCNMaterialProperty`, `SCNNode`, `SCNPlane`, a scene's `SCNPhysicsWorld`, a radial-gravity `SCNPhysicsField` and an
`SCNParticlePropertyController` by key-value coding. `tests/backports/host/scenekit-defaults/refresh.sh` runs it
against the host and writes `scenekit-defaults-expectations.h`; `tests/backports/device/scenekit-defaults.m` runs it
against the port and holds each answer to the host's (numbers to six significant digits, one unit in the last digit
for a CGFloat that is a float here and a double there; a mask of every bit is compared as "all bits", since
`NSUIntegerMax` has the platform's width).

The first run, on the emulator (iPhone2,1 6.0, 2026-09-24), found 22 port defaults that were not SceneKit's, and
they are SceneKit's now:

- `SCNLight`: `shadowColor` black (was nil), `spotOuterAngle` 45 (was 0; an archive without the key no longer resets
  it to 0).
- `SCNCamera`: `orthographicScale` 1 (was 0).
- `SCNParticleSystem`: `birthRate` 0 (was 100), `particleSize` 1 (was 0.1), `emittingDirection` (0, 1, 0) (was zero,
  while the decoder already used (0, 1, 0) for a missing key), `affectedByGravity` and `affectedByPhysicsFields` NO
  (were YES, in `init` and as the decoder's fallback). Apple's documentation says 1 for `birthRate`; the running
  framework answers 0, and the running framework decides.
- `SCNMaterial`: every slot had nil contents. SceneKit's are white for diffuse, normal, transparent, multiply and
  ambient occlusion; black for specular, reflective, emission, displacement, self-illumination and metalness; and
  sRGB 0.484529 for ambient and roughness, which is 0.2 in linear light (sRGB-encoding 0.2 gives 0.48453), so it is
  made as `+[CharonSCNCoding colorWithLinearWhite:0.2]`.
- `SCNNode`: `rotation` (0, 0, 0, 0) (was (0, 0, 1, 0)).

## Demand row that is not SceneKit's: `SCNSceneRenderer.audioEngine`

`coordination/corpus/crash-demand-top.tsv` (2026-09-23) ranks `SCNSceneRenderer.audioEngine` 126th,
CRASH-ON-USE, callers `delta` and `provenance`. The row is false: neither application links
`SceneKit.framework`. `otool -L` on `Delta.app/Delta` and `Provenance-iOS.app/Provenance` shows only a
weak `libswiftSceneKit.dylib`, which the Swift overlays pull in on their own. Provenance's
`ReplayKit.framework` load command, found by the same scan, is the control that the scan finds a
framework when it is there. The `audioEngine` selector those binaries use is their own
(Delta's `Systems.framework`, Provenance's `PVCoreAudio` package). The demand engine counted it by name
alone: `protocol-owner: not class-symbol-verifiable, name-based count only`. It is not a reason to carry
`SCNSceneRenderer.audioEngine`. A real caller needs a binary that links SceneKit and reaches an
`SCNView`/`SCNRenderer`.
