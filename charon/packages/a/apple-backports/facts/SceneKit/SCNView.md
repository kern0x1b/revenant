# SCNView over OpenGL ES 2.0

SceneKit does not exist on iOS 6. `SCNView` here is a `CAEAGLLayer` view that draws the scene with this library's
own OpenGL ES 2.0 renderer (`SceneKit/CharonSCNRenderer.m`). Every rule below was measured against macOS SceneKit
(Metal, `SCNRenderer.snapshot` read back byte by byte in sRGB), not taken from the documentation. The programs that
measured it are in `tests/backports/host/scenekit`: `run.sh` (the matrix functions, node conventions and view
defaults the device test holds the port to), `frames.sh` (a device's snapshots against SceneKit's frames of the same
scenes) and `lighting/run.sh` (the lighting fits below).

## Which scenes Telegram draws

Telegram 12.9.2 (`git grep loadCompressedScene` in release-12.9.2) loads ten scenes, all gzip files in
`submodules/PremiumUI/Resources/`: `star2` (PremiumStarComponent), `coin` (PremiumCoinComponent), `gift2`
(GiftAvatarComponent and PremiumDiamondComponent; the diamond itself is `DiamondLayer`, not SceneKit), and seven that
carry no geometry, `badge`, `emoji` and `tag` (BadgeStarsView), `business` (BadgeBusinessView), `boost`
(BoostHeaderBackgroundComponent), `lightspeed` (FasterStarsView) and `swirl` (SwirlStarsView). Inventory (macOS
SceneKit loading each decompressed file, 2026-09-26, `tests/backports/host/scenekit/inventory.swift`): `star2` 15 nodes, one geometry (subdivided), four lights, seven
particle systems, physically based, 2 image slots; `coin` 20 nodes, five geometries, four lights, seven particle
systems, physically based, 10 image slots; `gift2` 14 nodes, no geometry, four lights, seven particle systems; the seven
others 3 to 8 nodes each, a camera, no geometry, no lights but `boost`'s ambient one, and one to six particle
systems: they draw nothing but particles, which this view does not draw (it says so once for each). The frames
and the lighting grid hold the first two. Decompressed, `star2` and `coin` are byte for byte the
macOS app's `star2.scn` and `coin.scn`; `gift2` is neither `gift.scn` nor `diamond.scn`.

- `star2`: one mesh, 1078 vertices, one polygon element of 777 polygons, `subdivisionLevel` 1, one physically based
  material; five particle systems.
- `coin`: five meshes (triangles, and two 3-segment line elements), physically based; five particle systems.
- `gift2`: no mesh; seven particle systems, a radial gravity field, the same lights.
- All three: an ambient light (grey 0.804, 1000), an omni `top` (750, attenuation 0-20), an omni `frontal` (8), a
  directional `rightside` (750), all at 6500 K; a camera with a vertical field of view of 60 degrees, z 1-100. No
  scene carries an archived animation: every animation Telegram shows is added by its own code.

## Conventions

- `SCNMatrix4` is row-major with the translation in m41..m43 and transforms row vectors; `SCNMatrix4Mult(a, b)` is a
  then b. Its memory is the column-major matrix OpenGL ES multiplies column vectors with, so the renderer uploads it
  as it is.
- A node's transform is scale, then rotation, then translation. `eulerAngles` (x, y, z) rotate about x first, then y,
  then z: `eulerAngles (0.3, 0.5, 0.7)` is `orientation (0.0521324, 0.2794439, 0.2937772, 0.9126272)`, reproduced to
  seven digits. Angles that were set come back unchanged (`(2.0, 0.2, -2.5)` reads back as given); angles derived
  from an orientation are the principal ones (`(0.1, 0.2, 0.3, 0.9274)` gives `(0.3272129, 0.3161869, 0.6783701)`).
- An archived node carries `rotation` and, in `star2`, `coin`, `gift2` and `boost` every node, in `emoji` and `tag` all but one, `orientation` too; `orientation` is the one read, and `rotation` where there is none (`badge`, `business`, `lightspeed`, `swirl`: their nodes have no `orientation`, and their `rotation` is the axis and angle of the `eulerAngles` they also carry in each of the eight nodes that carry them, and zero in the other six). `rotation` is all zero in `star2` (the removed SceneKit inventory).
- `SCNMatrix4MakeRotation` normalises its axis and answers the identity for a zero axis; `SCNMatrix4Scale` and
  `SCNMatrix4Rotate` apply before m and keep its translation; `SCNMatrix4Invert` of a matrix without an inverse
  answers the matrix itself; the equality functions compare with `==` (NaN unequal, -0 equal to 0).
- `contentsTransform` is archived as its sixteen floats; it maps `(u, v, 0, 1)` as a row vector.

## Lighting

Lighting is done in linear light and the result written sRGB-encoded. Colours of lights and of the colour slots are
linearised first. A light's intensity of 1000 is 1.0.

- The view vector runs from the fragment to the camera's position, also under an orthographic camera: the fit of
  the specular lobes is off until it does by the angle of the sampled pixel seen from the camera, 0.035 rad (the pixel lies 0.125 off the axis in x and in y, the camera 5 away; `fitspec.py` builds `V` from it).
  The exception is the coat of `selfIllumination` ("Physically based, the rest"): there `N.V` is taken against the
  camera's own axis, the same for every point (the fit of 432 pixels is within one level with `cos(theta)`; with the
  position, the six cases at tilt 1.3 were two to three levels dark, and with the axis in the specular terms 282 of
  the 1340 cases of the grid were two to four levels off). Two view vectors for one camera is what the measurements
  say; the shader takes the position for lights and a homogeneous `u_coatView` (the axis, `w` 0, for an orthographic
  camera) for the coat.
- Point lights (omni, spot) outside the physically based model are attenuated by
  `((end - d) / (end - start)) ^ exponent`, clamped, when `end > start`; at 0-20, exponent 2, d = 1, 2, 4 the light is
  0.90, 0.81, 0.64 of its value.
- Constant: the diffuse colour, whatever the lights.
- Lambert, Blinn, Phong: `ambient * al + diffuse * dl + specular * sl`, plus emission, times multiply, where `al` is
  the sum of the ambient lights and `dl` the sum of `N.L` times each other light. With `locksAmbientWithDiffuse` (the
  default) the diffuse colour stands for the ambient one. When no light but ambient ones reaches the surface, `dl` is
  1: a scene with no light draws the diffuse colour, and one with only an ambient light of 1000 draws it doubled.
  `selfIllumination` (linearised, times its intensity) adds to `dl` when any light but an ambient one is there, and
  does nothing when `dl` is that implicit 1: `diffuse * (sum of N.L + selfIllumination)`. Measured over 126 pixels of
  each of Constant, Lambert, Blinn and Phong (diffuse 0.25/0.5/1, selfIllumination 0 to 1, no light, ambient alone, a
  directional light at 0 and 1 rad, facing away, at half intensity, with an ambient light) and 30 more with a
  specular, an emission, an unlocked ambient slot and a selfIllumination intensity of 0.5 beside it: all 534 within
  one level of it (`lighting/selfillumination.swift`, `fitselfillumination.py`). Constant ignores it. **Retracted:** this file first gave the three models no
  selfIllumination term; the grid's four points per model showed it, and the port drew the same pixel whatever the
  value.
- Blinn's specular is `(N.H) ^ (128 * shininess) * N.L`; Phong's `(R.V) ^ (128 * shininess) * N.L`. Over 24 angles
  and four shininess values each, every one of the 96 pixels of each model is within one level of it (rms 0.29 at
  most; `lighting/fitspec.py`). An exponent of 132 * shininess is already off by up to two, and a view vector leaning
  away from the light costs Blinn 8 to 21 levels and Phong 16 to 42 (the worst of each shininess; a recomputation of `fitspec.py`'s model with the other sign of `V`).
- Physically based: diffuse `albedo * (1 - metalness) * N.L`, specular `pi * D * Vis * F * N.L` with GGX `D`
  (alpha = roughness squared), the height-correlated Smith visibility and Schlick's Fresnel with
  `F0 = mix(0.04, albedo, metalness)`. Fitted over 637 pixels (seven roughnesses, four metalness/albedo pairs, 24
  angles) the model is within one level of every one, rms 0.29 with Schlick's Fresnel, which the shader uses (0.28 with a constant one); over 190 more at grazing view angles, rms 0.23, where
  a constant Fresnel is off by up to 22 levels.
- Physically based, the rest: an ambient light adds `albedo * al`, not reduced by metalness; `selfIllumination` adds
  `D * selfIllumination * T` with `D = albedo * (1 - metalness)`, and `T` is not 1: `T = (1 - a) * max(1 - 1.140 g^5, 0) +
  a * (0.709 + 0.124 g^2 + 0.367 D)`, `a` the roughness squared and `g = 1 - N.V`. Found on Telegram's star2, whose frame
  the port drew 1.17, 0.96 and 0.69 levels too bright (its roughness is 0.45, and the plain product was the only term
  the grid had checked, at roughness 0.5 and view straight on, where `T` is 0.96 to 0.99): switching the slots off on both
  sides took the bias with selfIllumination alone, and 432 pixels of a quad with no light (`lighting/selfcoat.swift`) showed `T`
  independent of the albedo at roughness 0, growing with it above, linear in `a` at every angle, and depending on the
  metalness only through `D`. `lighting/fitselfcoat.py` searches the four constants: worst 1 level, rms 0.44 over the
  432 pixels. The published split-sum model does not reproduce it (`lighting/modelselfcoat.py`): with the energy the specular coat takes, `F = f0 A + B`
  (Karis's `EnvBRDFApprox`, or A and B integrated for GGX), the term `D * selfIllumination * (1 - F)` is off by up to 24 levels
  (69 and 72 of the 432 pixels within one level; worst 24 at every angle from 0 to 80 degrees and 12 to 24 at every roughness).
  Two things are structural: at roughness 0 the measured `T` is 0.99 to 1.00 face on and does not depend on the albedo or
  the metalness, where `1 - F` is 0.95 (`f0` 0.04) to 0.88 (metalness 0.45) and grows with `f0`; and above roughness 0.4 the
  measured `T` falls with roughness (0.80 at roughness 1, albedo 0.5, face on) and rises with the albedo (0.95 at 0.8), where
  `1 - F` rises to 0.98. At grazing 80 degrees, roughness 0, `T` is 0.56 against 0.63. So the form is a fit, not SceneKit's own
  formula (nothing of it is public); the ambient light's term has no
  roughness in it (measured at 0 to 1). The ambient slot changes nothing (`litPerPixel` was probed once and found to change nothing; that probe was not kept, and the renderer does not read it). A directional
  light of intensity I is `I / 1000`; an omni or spot light is `I / (pi * d^2)`, and when its attenuation end is set,
  times `(1 - (d / end)^4)^2`, zero beyond the end; the attenuation start and falloff exponent change nothing
  (measured from d = 2 to 18 with ends 12 and 20, starts 0 and 5, exponents 1, 2 and 4: within one level of the
  window at every point: the grid's `PBR omni window` cases, 15 of them; at d = 14, end 20 the window is 0.577). **Retracted:** this file first said the
  attenuation distances do not apply in this model; that was measured at d <= 4 only, where the window is >= 0.997.
  With no light at all the surface is black.
- Precision: on the iPad 2 (SGX543, iOS 6.1.3) a fragment mediump float holds 10 bits over 2^-15..2^15, a half float,
  and highp 23 bits (`scenekit-lighting` asks `glGetShaderPrecisionFormat`). The normal therefore runs highp from the
  attribute to the fragment (a lowp float holds 8 bits over -1 to 1). A `uniform sampler2D` with no qualifier is lowp in a
  fragment shader (GLSL ES 1.00, 4.5.3), whatever `precision highp float` says, so the shader declares `precision highp sampler2D`;
  switching it (iPad 2, 2026-09-26, `scenekit-frames` on coin and star2 before and after) moved every frame's bias by at most
  0.01 level, and the grid's histogram of errors (with dark colours as images in the diffuse slot among its cases) did not move: it is not the cause of the dark metal
  ("Open"). With a mediump one the grazing cases of the grid were up to 12 levels off (roughness 0.2
  seen at 0.9 rad: 142 for SceneKit's 130); with a highp one all of the 1304 cases of that date were within one level.
- The scalar slots (`metalness`, `roughness`) read a colour's first component as it is: grey 0.45, the number 0.45
  and white at intensity 0.45 draw the same pixels; so do greys of 0.2 in sRGB, linear sRGB, linear grey, generic
  gamma 2.2, calibrated and device white and Display P3.
- A new material's slot is drawn from SceneKit's own value for it, a colour in linear light, while `contents` answers
  that value sRGB-encoded: the default roughness answers grey 0.484529 and draws like roughness 0.2 (directional light
  at 0 and 0.3 rad: 255 and 135, as 0.2 does; 0.484529 draws 168 and 151). The very colour `contents` answered,
  assigned back, draws like 0.484529, also after an archive round trip. It stays the default through a read of
  `contents`, `copy`, an archive round trip (a material's archive leaves out every property never set; setting any
  value of one, an intensity too, puts it in) and `contents = nil`, and an intensity scales it (0.5 draws like 0.1:
  126 at 0.3 rad); measured on macOS 27 (`lighting/defaultslot.swift`). The port marks the properties `-[SCNMaterial init]` makes as
  holding the slot's default until `contents` is set, and draws them from the linear value in every slot. For a colour
  slot this changes nothing (the encoded default linearises to the same value); for roughness it is the difference
  between 255 and 168. **Retracted:** handoff 2 of the band guessed that SceneKit holds the default as linear 0.2 and
  a scalar slot reads the colour's own first component; the colour `contents` answers is sRGB, and it is the untouched
  default, not the colour, that draws as 0.2.
- Whether a slot's values are sRGB colours is the slot's: every property of `star2` and `coin` carries a `sRGB` flag,
  set on diffuse, ambient, specular, emission, reflective, multiply, selfIllumination, clearCoat and
  clearCoatRoughness, clear on transparent, normal, ambientOcclusion, metalness, roughness, displacement and
  clearCoatNormal.
- The alpha, all models: the node's opacity times the transparent slot's alpha. Physically based, times the diffuse
  alpha; `transparency` changes nothing there. The other models: times `transparency` and the diffuse alpha twice
  (a diffuse alpha of 0.5 is stored as 64 in constant, lambert and blinn alike). The colour is premultiplied in
  linear light before it is encoded: white lit to 0.878 at transparency 0.5 is stored `(177, 177, 177, 128)`.
- Constant: `(diffuse + emission) * multiply`; the other models add emission and multiply the same way.
- A spot light's cone is linear in the cosine of the angle between the half inner and half outer angles, not a
  smoothstep: inner 20, outer 60, six cases each in the grid (`spot` cases, within one level); a smoothstep between the same angles would draw another pixel (the two pixels once quoted here, 198 and 205 at 20.8 degrees, came from a probe not kept, and a recomputation gives 203 at 21.06 degrees).
- A normal or ambientOcclusion slot holding a colour instead of an image changes nothing, in every model.
- macOS keeps drawing a slot's previous colour after its contents are set to nil (`selfIllumination` white 0.75, then
  nil, draws as white 0.75); a divergence of the Metal renderer this port does not copy: nil is the slot's default.

## Textures

- A new material's slots filter between mipmap levels by the nearest level (`mipFilter` 1 in every one of the 16
  slots), while a property made alone answers 0 (`scenekit-defaults-expectations.h`). It shows wherever an image is
  drawn smaller than it is: the animation cases' 256-texel gradient drawn at 8 pixels, 32 texels to the pixel, reads
  level 5 and draws (206, 84) where level 0 gives (205, 82); the shimmer, whose transform halves the image, reads
  level 4 at 16 texels to the pixel, so its clamped edges draw 248 and 8 where level 0 gives 255 and 0. Set to 0,
  macOS draws exactly the level-0 values, and at 256 pixels, where no level but 0 is read, both agree
  (`host/scenekit/animation/mipfilter.swift`, macOS 27). The port gave every property 0 until this was measured: the
  `gradient` and `shimmer` cases of `scenekit-animation` fell outside their tube by 2 and 8 levels at exactly those
  pixels.
- A colour slot's image is an sRGB texture: its mip levels are averaged, and every sample filtered, in linear light,
  and every level is made from the level before it as that is stored, in 8 bits. Metal's `generateMipmaps` of the
  256-texel ramp in an `rgba8Unorm_srgb` texture gives level 5 as 18, 49, 81, 112, 144, 176, 208, 240, where the same
  bytes in an `rgba8Unorm` texture give 16, 48, 80, 112, 143, 175, 207, 239 — the plain mean of each 32 texels, which is
  what GL ES 2.0's `glGenerateMipmap` makes. The exact linear mean of level 0 gives 17.19, 48.46, 80.13: Metal's 18 is
  the linear mean of level 4's stored 8 and 25 (18.06), not a rounding of 17.19. That rule — a texel of level n + 1 is
  the linear mean of its 2x2 texels of level n as stored, kept as the byte nearest its encoding — gives 217 of Metal's
  255 texels of levels 1 to 8, each made from Metal's own level above it (the fit was `fitmipmaps.py`, since deleted with no caller left). Of the 38 it misses, 37 lie within 0.03 of a tie between two bytes, which Metal breaks either way
  (0.50 into 1, 2.50 into 2), and one, level 4's texel 1 (24.29 from level 3's 20 and 28, Metal 25), is not explained;
  chained from level 0 the rule's own levels (`host/scenekit/animation/srgblevels.swift`) then stray from Metal's by one
  here and there (level 5: 17, 49, 80, 112, …). SceneKit samples the levels of an `MTLTexture` it is given as they are,
  under `mipFilter` linear (nearest reads level 0 alone, `host/scenekit/animation/givenlevels.swift`); given Metal's
  own levels that way it draws its own render of the image exactly, 320 of 320 pixels. Against SceneKit's 8x8 renders of
  the gradient at five translations (320 pixels, `host/scenekit/animation/mipmaps.swift`, its fit `fitmipmaps.py` since deleted, macOS 27,
  Apple M4 Pro), filtered in linear light: Metal's own level gives 281 exact, the rule's level 179, the exact mean from
  level 0 (the port before) 130, none of them off by more than 1; the exact mean filtered in the encoding misses by up
  to 55 where the repeat wraps from 240 to 17, and the plain mean filtered in the encoding — the port before that,
  decoding in the shader after the texture unit filtered — matches 1 pixel and misses by up to 56. The 39 pixels even
  Metal's own level misses are the texture unit's rounding, not the level: SceneKit given the rule's levels is 281 of 320
  exact against the rule's model too.
  The iPad 2 has no sRGB texture to do this with: its GPU (`PowerVR SGX 543`, `OpenGL ES 2.0 IMGSGX543-73.16.1`,
  iOS 6.1.3) lists 35 extensions and no `GL_EXT_sRGB` (`tests/backports/device/gl-extensions.m`, 2026-09-24), though the SDK's
  header declares it. It does list `GL_OES_texture_half_float` and `GL_OES_texture_half_float_linear`. So a colour
  slot's texture holds the image in linear light, premultiplied, as half floats (a half's 11 bits keep every 8-bit
  sRGB value apart), its levels built by the port by the rule above, in doubles, ties half up (the colour's byte and
  alpha's byte kept apart, the colour straight: how Metal's levels treat a translucent texel is not measured), and the
  texture unit filters linear light;
  the shader only divides by alpha. The data slots (transparent, metalness, roughness) keep 8-bit textures and
  `glGenerateMipmap`, as SceneKit's are not sRGB: the same image in a colour slot and a data slot is two textures. A
  GPU that filters no half float gets the encoded image, and the log says once that it is filtered in the encoding.

## Animations

Telegram's star and coin components (release-12.9.2) call `addAnimation:forKey:`, `removeAnimationForKey:`,
`animationKeys` and `presentation` on a node and `addAnimation:forKey:` on a material property, with
`CABasicAnimation`, `CASpringAnimation` and `CAAnimationGroup`; nothing in PremiumUI calls `runAction:` or uses
`SCNAction`, `SCNTransaction` or `SCNAnimation` (`git grep`). macOS SceneKit, sampled every 4 ms by rendering
(`tests/backports/host/scenekit/animation/series.swift`, the calls those components make):

- SceneKit evaluates the animations at the time a frame is rendered for, and the presentation node answers what the
  last frame drew: between frames it does not move.
- An animation whose `beginTime` is 0 begins at the first frame after it was added; any other `beginTime` is absolute
  media time: the flash's `CACurrentMediaTime() + 0.1` begins 0.1 s after the add, and the shimmer group's
  `beginTime = 1.0` runs in phase with `(media time - 1) mod 4`, whenever it was added.
- The curves are Core Animation's: ease-out and ease-in-ease-out are the cubic Beziers (0, 0, 0.58, 1) and
  (0.42, 0, 0.58, 1); autoreverses and an infinite repeat make the period twice the duration; a group's children run
  in the group's local time with their own `beginTime` and fill mode.
- A `CASpringAnimation` follows the damped spring of `mass`, `stiffness`, `damping` and `initialVelocity` (the
  velocity in fractions of the way per second): within 0.0016 rad of SceneKit's samples where the spring is slow and
  within 1.6 ms of them where it is fast.
- When its active duration ends, an animation with `removedOnCompletion` is removed and the node shows its model
  value again, also with `fillMode` forwards (the tap rotation); without it, the end value stays and the key remains
  (the flash's opacity). `removeAnimationForKey:` shows the model value at the next frame.
- The delegate hears `animationDidStart:` at the first frame after the add, also when `beginTime` is later, and
  `animationDidStop:finished:` with YES when the active duration ends (also when the animation stays) and with NO when
  it is removed before; both after the frame, on the main queue (SceneKit sends none while the main run loop does not
  run).
- `presentation.eulerAngles` is the animated value itself, not angles derived back from a rotation (4.426 during a
  spring to 2 pi).
- A material property's animated `contentsTransform` is not readable on macOS: `-[SCNMaterialProperty
  contentsTransform]` of the presentation node's material crashes inside SceneKit (EXC_BAD_ACCESS). It is measured
  in pixels instead, on a quad lit constant whose image's red is u and green is v.
- `-[SCNNode copy]` keeps the name, geometry, light, camera, particle systems (the same objects), transform, opacity
  and animations, and has no children; `-clone` is the same with every child cloned. This port's copy had copied the
  children until this was measured.

This port evaluates them the same way (`SceneKit/CharonSCNAnimation.m`) for the key paths measured: `eulerAngles`,
`scale` and `opacity` on a node, `contentsTransform` on a material property; `position` is evaluated the same way and no series has recorded it. Another key path, or an
animation class other than a basic, spring or group animation (a `CAKeyframeAnimation` on a node, for one), is said
once in the log and not evaluated.

How it is held: `tests/backports/device/scenekit-animation.m` runs the same eight cases through the port, and
`tests/backports/host/scenekit/animation/compare.py` holds each sample within a tube around SceneKit's curve, 5 ms
across in time and 1e-3 (a node's value) or one level (a pixel) in value; the end of an animation within the larger
sampling gap and 5 ms; the delegate's calls in order, flag and within 20 ms. Three runs of SceneKit held against each
other stay within 0.81 of the tube (the worst is the gradient's pixel rounding), and the negative controls,
SceneKit's own series with the tap rotation 5% long and the spring 22 stiff instead of 21, fall outside it on every
pairing (2.16 and 6.11 at least).

On the iPad 2 (iPad2,2, iOS 6.1.3, 2026-09-26, against the series `record.sh` wrote on macOS the same day): all eight cases within the
tube (worst 1.00, the gradient's 97 samples; the shimmer 0.29), and both negative controls outside it (2.17 and 6.12). The
gradient was outside on 2026-09-24 (3 of its 105 samples, 2.27 before its levels were averaged in linear light): the port
now builds each mip level from the stored 8-bit level above it ("Textures"), which SceneKit's own frames follow. Metal's own
level bytes are the other comparison, reported and not held: the gradient's worst is 1.12 of the tube with 2 samples outside,
the shimmer's 0.66 with none (the band's earlier run of the same day gave 1.19 with 5 outside and 0.62 with none). The tube is
not widened for it.

## What the view says it does not draw

The first frame of each scene lists in the log, once, what the scene has and this renderer does not draw: particle
systems (by the nodes that carry them), a geometry's subdivision level, a clear coat, a normal, ambient occlusion or
displacement map from an image, a reflective slot that is not black, and a background or lighting environment that
shows anything; the lighting model `ShadowOnly`, which is drawn as Blinn; a blend mode other than alpha, drawn as alpha; a light
of a type this renderer does not draw (IES, area, probe: a node lit only by such lights is drawn unlit); a light's shadow
(`castsShadow`) and its colour temperature. `jitteringEnabled` set to YES says once that no jittered frames are accumulated. `gift2`, which is only
particles, says so instead of drawing empty without a word.

## Wrap and images

- Wrap modes: clamp, repeat and mirror are GL's; clamp to border is done in the shader. iOS has no `borderColor`
  (the SDK's header does not declare it), so outside the image a slot reads transparent black, which is what an iOS
  GPU's Metal sampler can clamp to (reasoned, not measured on iOS).
- An image named by the archive is looked up beside the scene's file, then in the application's main bundle.
  Telegram writes the scene to its temporary directory and ships the images in its bundle.
- Every texture is resampled to powers of two, since OpenGL ES 2.0 repeats, mirrors and mipmaps nothing else, and
  gets mipmaps ("Textures" says how).

## What changes the frames of Telegram's scenes, and by how much

Each switched off on the oracle alone, compared with the scene as it is (`compare.py`, 256x256, particles off):

| Switched off | star2 | coin |
| --- | --- | --- |
| subdivision | IoU 0.9875, mean 1.26, p95 6 | no change |
| clear coat | mean 0.62, p95 1 | mean 0.31, p95 1 |
| normal slot (a colour) | mean 0.13, p95 1 | none |
| lighting environment (a transparent colour) | none | none |
| emission at t = 0 | none | none |

## The view

macOS `SCNView`, measured: `preferredFramesPerSecond` 0, jittering off, `pointOfView` the scene's first camera node
once a scene is set (and nil stays nil); `-snapshot` sends the delegate `update`, `didApplyAnimations`,
`didSimulatePhysics`, `didApplyConstraints`, `willRenderScene` and `didRenderScene` once, on the calling thread, at
time 0. Telegram's components wait for `didRenderScene` before they show anything, and call `snapshot()` right after
setting the scene. The iOS header gives `antialiasingMode` None and `rendersContinuously` NO as defaults.

This port draws on the main thread from a `CADisplayLink`; SceneKit draws on a thread of its own.

## Not done yet

Named so that nobody reads them as done: jittered accumulation (`jitteringEnabled` is kept, nothing accumulates),
idle frames (the view redraws every display frame), `antialiasingMode`, `allowsCameraControl`,
`playing`/`loops`/`sceneTime`, hit testing and projection, particles, animations of key paths other than the five
measured and of keyframe animations on a node, `removeAnimationForKey:fadeOutDuration:`, subdivision, clear coat, normal and ambient occlusion maps from images, reflective and
environment lighting, the lighting model `ShadowOnly` (drawn as Blinn), blend modes other than alpha (drawn as alpha), lights of
the types IES, area and probe, a light's shadow (shadow maps are shader work the SGX can do, so this is work not done, not a
boundary) and its colour temperature, the default camera SceneKit makes for a scene without one (the view then draws from the
origin down -z with a 60 degree camera), and more than eight lights on one node (the rest are logged and not drawn).

## Open

What this view does not yet do, and what it does differently from macOS SceneKit without a known cause, with what each
costs in Telegram's two drawn scenes ("What changes the frames of Telegram's scenes"). None is closed by a bound on the
frames (see "The frame tolerance").

- **Subdivision** (star2): drawn unsubdivided; the frame's coverage is 0.9875 of macOS's with it. Not done: a subdivision
  of the mesh at the level the scene asks (`subdivisionLevel`), the way SceneKit does it, which nothing here measures yet.
- **Clear coat** (star2, coin): decoded, not drawn or encoded; the frames' mean is 0.62 and 0.31 levels off with it
  switched off on the oracle. Not done: the clear coat's lighting term, which needs its own grid on macOS.
- **Normal and ambient occlusion maps from images**: a colour in those slots changes nothing and is what the scenes
  hold (mean 0.13, p95 1); an image in one is said once and not drawn.
- **Particles**: not drawn, by any of the ten scenes' emitters (seven have nothing else); said once for each scene.
- **star2's shift**: with every fit in, star2's drawn frame is off macOS's by -0.15, -0.16 and -0.14 levels on average
  (mean 0.95, p95 2), which the coverage lost to the missing subdivision does not explain by itself.
- **Lit metal at roughness 0.2 on curved, textured geometry** is about a level and a half too dark under a point or a
  directional light (coin -1.25/-0.81/-1.76 with only its omni lights, -1.49/-0.87/-1.81 with only the directional one;
  star2 with metalness 1 and roughness 0.2 everywhere -1.65/-1.35/-1.74, p95 11; iPad 2, 2026-09-26): unexplained. The
  flat-quad grid does not show it (all its cases within one level but the seven known open ones). Ruled out by
  measurement: the sampler's precision, which is lowp when a shader does not say otherwise; with `precision highp sampler2D`
  the biases move by 0.01 at most, and dark colours as images in the diffuse slot are in the grid and within one level.
  Candidates left: the specular `D` and visibility at alpha 0.04 in the shader's precision, the omni light's `L` per
  fragment, the half-float normal. The next probe: a sphere (curved) case with an omni light, metalness 1 and roughness
  0.2, in the grid on macOS and on the port.
- **Unchecked in the renderer** (named; the iPad 2 is the only device asked): blending mixes sRGB-encoded
  values, and only a premultiplied colour over black was compared with macOS, so a translucent surface over another colour
  is unmeasured; a texture is uploaded with no check of `GL_MAX_TEXTURE_SIZE` (4096 on the iPad 2) and no `glGetError` after
  `glTexImage2D`, so what an image larger than the limit gives is not known; a mesh with an index above 65535 is drawn with
  `GL_UNSIGNED_INT` indices and no check of `GL_OES_element_index_uint` (present on the iPad 2, `scenekit-lighting` prints
  it), so what a device without it does is not known either.
- **Animation timing and values left unmeasured** (the log says the timing members once, `CharonSCNAnimation.m`): a pause
  before the animation's first frame stores the media time minus a begin of 0; an additive animation of a matrix adds
  the components one by one (`CharonSCNAdd`), which no series has compared with SceneKit; what happens to the value when a
  finished animation's removal meets another animation on the same key path is not measured. `position` is evaluated as
  the other four key paths are and no series has recorded it: it is not held to macOS's.
- **The smallest roughnesses**: below roughness 0.05 macOS SceneKit leaves the GGX formula. `cases ladder` (metalness 1, a
  directional light of 250, albedo 1) prints macOS's pixel face-on: 0 up to roughness 0.0125, then 55 at 0.015, 78 at
  0.0175, 95 at 0.02, 193 at 0.03, and 255 (saturated) from 0.04; the formula, which the port draws, gives more than 0 at
  0.01 (the port drew 19 to 43 where macOS draws 0) and 5 to 8 levels less than macOS at 0.02 (90, 166, 13 against 95, 174,
  15 at three angles). The grid holds roughness 0 and 0.05 (`PBR low roughness`, 24 cases, all within one level); the port's
  shader keeps no floor on alpha (a floor of 0.002 was there once, unmeasured; it moved every roughness below 0.045 to one value).
  What macOS does between 0 and 0.05 is not the formula and not known: a half-precision `alpha^2` would flush to zero
  near 0.0135, and does not explain 0.02.
- **`presentationNode`** is brought up to date when asked for; macOS brings it up to date when a frame is committed, so
  a change of the model shows in macOS's presentation node one frame later.
- **A node archived after a matrix was set** encodes position, orientation and scale, not the matrix: a shear does not
  survive an archive.

## Measured on a device

- Shade (`xmake emulate`, iPhone2,1 6.0) has no OpenGL ES 2.0, measured 2026-09-23: its log says
  `[gles] renderer="Shade GLES 1.1 Vulkan (SwiftShader Device (LLVM 10.0.0))"` and
  `-[EAGLContext initWithAPI:kEAGLRenderingAPIOpenGLES2]` answers nil in a daemon there — a gap for shade to close.

So the view is checked on hardware, iOS 6.1.3:

- `tests/backports/device/scenekit.m`: 54 of 54 checks pass, 52 of them against macOS SceneKit's answers and 2 local ones (the
  snapshot is the view's size, and the host's answers are readable) (iPad 2, 2026-09-26; the earlier "33 of 33" counted the
  same 2 local checks among the macOS ones, and ran on the iPhone 4S 2026-09-23 and the iPad 2 2026-09-24)
  (`tests/backports/host/scenekit/run.sh`): the matrix functions, the node conventions, SCNView's defaults, and the
  delegate messages of `-snapshot` (update, didApplyAnimations, didSimulatePhysics, didApplyConstraints,
  willRenderScene 0.0, didRenderScene 0.0).
- `snapshot()` of `star2` and `coin` at 256x256, particles removed, against macOS SceneKit's frame
  (`tests/backports/host/scenekit/frames.sh`, 256 points at scale 1), iPad 2 (iPad2,2, iOS 6.1.3, 2026-09-24, the
  build of the linear-light textures): "drawn" is the port's frame with nothing it does not draw against macOS's frame
  of the same switched scene; "full" is the scene as it is; "wrong D" the port with every roughness D too high against
  macOS's switched frame.

  | scene | drawn | full | wrong 0.02 | wrong 0.05 | wrong 0.1 |
  | --- | --- | --- | --- | --- | --- |
  | star2 | IoU 0.9991, mean 1.59, p95 3 | 0.9874, 2.42, 6 | mean 1.72, p95 3 | 1.88, 3 | 2.09, 3 |
  | coin | IoU 0.9999, mean 2.09, p95 3 | 0.9999, 2.24, 3 | mean 2.24, p95 3 | 2.51, 6 | 2.93, 11 |

  The port's full and drawn frames are identical (the switches take nothing away that it draws). star2's missing
  coverage is the subdivision it does not do: macOS's own frame without it is 0.9875 of the frame with it.

### The frame tolerance

Not set. What is left between the frames is not yet shown to be noise. star2's drawn frame was brighter than SceneKit's
on average by 1.17, 0.96 and 0.69 levels in red, green and blue (5029 of its 7449 pixels off by 1, 1919 by 2); the cause
was the selfIllumination term of the physically based model ("Lighting"), and with it corrected (iPad 2, 2026-09-26) the
frame is off by -0.15, -0.16 and -0.14 on average, mean 0.95, p95 2. coin's went from -0.08, -0.24, -0.16 to -0.71, -0.57,
-0.97 (mean 2.09 to 1.58). Isolated by switching (iPad 2, 2026-09-26, `scenekit-frames` `nolight+T`, `metalness=V`,
`roughness=V`, the same on macOS through `render.swift`): it is not the selfIllumination term (`noselfillumination` -0.67,
-0.55, -0.94) and not the ambient light (only the ambient light on: 0.00, -0.17, -0.13); with only the omni lights
on it is -1.25, -0.81, -1.77, with only the directional light -1.49, -0.87, -1.81; with every roughness 0.9 it is +0.09,
-0.03, -0.03 and with every metalness 0 it is -0.11, -0.20, -0.16. So the port's lit metal at roughness 0.2 (coin's
materials, metalness 1) is about a level and a half too dark under a point or a directional light, on curved
geometry with textures, where the flat-quad grid (1415 of its 1422 cases within one level, off by 0 in 1277, and the seven known
open cases at roughness 0.01 and 0.02; iPad 2 2026-09-26) does not show a sign. star2 with every metalness 1 and roughness 0.2 shows it larger: bias -1.65, -1.35, -1.74, p95 11, and 61 with the
ambient light off. It is unexplained, and open (below). A frame bound would still not tell a renderer
whose roughness is 0.05 off (star2's mean 0.95 against 1.03), so none is set; a bound over an unexplained bias would
hide a cause. Nor would a bound on these numbers tell a renderer whose roughness is 0.02 off (star2's mean 1.59
against 1.72, p95 3 in both); the lighting grid does (`scenekit-lighting`: the port misses a renderer with roughness 0.02 too large on every one of the 256 cases where its pixel is more than two levels from SceneKit's; an exponent 3% too large is within two levels of SceneKit's on every case, and no check holds it). The earlier
bound, IoU >= 0.97, mean <= 12, p95 <= 40, was fixed before any comparison and is withdrawn; the iPhone 4S run it was
held to (star2 mean 3.79, coin 3.23) predates the lighting fixes.

- The first snapshot of a scene costs what compiling its programs and loading its images costs (iPhone 4S: star2 1085 ms, coin
  228 ms); later ones 7.6 ms (coin) to 14.5 ms (star2) at 256x256.
