# ModelIO on iOS 6: the asset, the mesh, the material, the voxel

Measured 2026-09-27 for `registry/ModelIO/ios9asset.json` (359 rows: 50 classes, 157 methods, 152
properties) and the three classes of `registry/ModelIO/ios9.json`.

## The wall this runs into

iOS 6 carries no ModelIO at all. The 6.1.3 armv7 dyld cache holds no `MDLAsset`, no `MDLMesh`, no
`MDLTexture` and no `MDLVertexDescriptor`: `~/.charon/dyld/6.1.3/selectors_armv7.txt`, the release's
whole selector table, has no `vertexAttributeDataForAttributeNamed:`, no `faceVertexIndices`, and no
selector of any of the classes below. The framework arrived in iOS 9. So there is nothing on the
release to answer with, and the work is building it.

`MDLVertexDescriptor`, `MDLVertexAttribute` and `MDLVertexBufferLayout` were already carried, in
`MetalKit/MDLVertexDescriptor9.m`, for MetalKit's vertex-descriptor bridge; `VertexDescriptor.md`
records that pass and its narrower scope. This pass carries the rest.

## What the port builds

**The object graph.** `MDLObject` is a named node with a transform, a set of components keyed by the
protocol each of them answers to, and children. `addChild:` and a container reached through
`children` both make the child's `parent` this object, `path` is the slash-separated chain of names
from the root, and `boundingBoxAtTime:` is the union of the boxes of the children, each of them
brought into this node's own space by the transform of the whole chain above it. A node with no
children has the zero box.

**The transform.** `MDLTransform` holds a real `matrix_float4x4` and its samples, and reads the
translation, rotation, shear and scale back off that matrix in the order the header describes: the
rotation is a product of the three axis rotations in X, Y, Z order, and the shear is read off the
normalised basis. A sample set at a time already held replaces that sample rather than standing
beside it, and a time before the first or after the last sample falls on the first or the last, as
every animated value here and on the host reads there. `MDLTransformStack` is the product of the
operations it holds, in the order they were added; each operation reads one animated value and turns
it into a matrix, and the value is findable by the name the operation was added under.

**The animated values.** One shape behind all of them: a time and up to sixteen components, held in
order, with linear or constant interpolation between two samples. Every concrete class converts to and
from its own type at that boundary and nothing else. `precision` is double only once a double has
been set, which is what the header's own default of float means.

**The mesh.** A vertex buffer of real interleaved bytes - position, normal, texture coordinate at
twelve, twelve and eight - with a descriptor saying where each sits and a submesh over the indices.
`boundingBox` is read off the positions, not stored. `vertexAttributeDataForAttributeNamed:asFormat:`
gives the same bytes back when the format is the one stored and reads them component by component
into a new buffer when it is not, using each format's own component width read off its bit range.
`indexBufferAsIndexType:` re-reads the indices at the depth asked for rather than reinterpreting the
bytes, which is what a 16-bit and a 32-bit index mean by the same number. The generators - plane,
box, ellipsoid, cylinder, cone - lay down real vertices, real normals and real texture coordinates,
with the caps and the quads asked for. The icosahedron, the hemisphere, the capsule, the
subdivision, the tangent basis and the unwrapped texture coordinates are **not** carried yet.

**The material.** A real set of named properties. The value a property is given decides its type, and
every value spelling reads that same value: a `float3` read back as `float4` is the three components
and a one, which is what a renderer wants from a scalar. `luminance` is the Rec. 709 weighting of a
colour, of a float, or of the first components of a vector. A physically plausible scattering
function carries the eight properties of the older one plus the eleven of its own, and its version
is 1.

**The texture.** A real block of texels. `texelDataWithTopLeftOrigin:` and
`texelDataWithBottomLeftOrigin:` are the same bytes with the rows flipped, `imageFromTexture:` is a
CGImage for the 8-bit channel counts CoreGraphics reads - and **nil** for any other encoding, which
is a real answer rather than a picture of something else. `writeToURL:` goes through ImageIO.

**The asset.** `-initWithURL:` reads the file the URL names:

- **Wavefront OBJ** - `v`, `vn`, `vt`, `f` with `o` and `g` opening an object and `usemtl` a
  material. Corners that name the same position, normal and texture coordinate are one vertex, so the
  file's own sharing of its vertices is the sharing the mesh has. A face of n corners is n - 2
  triangles. A vertex the file gives no normal for is given the sum of the normals of the faces that
  meet there, and a direction of no length is the Y axis, so a face of a mesh that names no normals
  still points where the file's own winding says it points.
- **Stanford PLY** - the ASCII and the binary little-endian form, and a header whose elements and
  properties are read as the header states them, so a property the port does not know is skipped by
  its own size. A face list is fanned into triangles as the object format is.
- **ASCII Universal Scene Description** - a `def Mesh` prim's `point3f[] points`, `int[]
  faceVertexCounts` and `int[] faceVertexIndices`.

`canImportFileExtension:` answers yes for exactly those three, and `canExportFileExtension:` answers
no: nothing the port reads is written back out yet, and `exportAssetToURL:` says so with an error
rather than writing a file that is not the asset. `exportAssetToURL:` and
`canExportFileExtension:` are the two rows registered here that answer "not yet" - they are present
and honest, which is what the rule asks for, but a caller that exports gets no file.

**The voxel array.** A box of space divided into cubic voxels and a set of which are filled. The
index of a voxel is where it sits in that division, the data behind it is read voxel by voxel, the
index of a point in space and the point at the centre of a voxel are the two directions of the same
division, and `union`/`intersect`/`difference` with another array put the other array's voxels into
this one's space through the two boxes they sit in. `setVoxelsForMesh:` fills every voxel the mesh's
own triangles pass through, widened by the patch radius.

## The one class of this surface a release carries without exporting: `MDLMeshBufferZoneDefault`

Measured 2026-10-04 with `apple.objc.inventory` and `apple.dyld` over the caches this package is
built for, one class and one export table at a time:

| release | the class in ModelIO's `__objc_classlist` | `_OBJC_CLASS_$_MDLMeshBufferZoneDefault` |
| --- | --- | --- |
| 6.1.3 - 8.4 (armv7) | absent (no ModelIO at all) | absent |
| 9.0, 9.1, 9.2, 9.3, 9.3.5, 9.3.6 (armv7) | present: superclass `NSObject`, six own methods (`-initWithCapacity:allocator:`, `-capacity`, `-allocator`, `-reserveMemory:allocator:`, `-cancelMemory:`, `-cxx_destruct`), adopting `MDLMeshBufferZone` | **no image exports it**, nor its metaclass |
| 10.0.1, 10.1, 10.2, 10.3, 10.3.4 (armv7s) | present, the same six methods | **no image exports it** |
| 11.0, 12.0 (arm64) | present, the same six methods | exported by ModelIO, metaclass with it |

`_OBJC_CLASS_$_MDLMeshBufferDataAllocator`, `_OBJC_CLASS_$_MDLMeshBufferData` and
`_OBJC_CLASS_$_MDLMeshBufferMap` are exported by ModelIO from 9.0 on, so the allocator that makes a
zone is the release's own from 9.0 up and the port's only below 9.0. That is what the SDK says too
(`MDLMeshBufferZoneDefault` is `API_AVAILABLE(... ios(11.0))` at `MDLMeshBuffer.h:274`) and the registry's
`introduced` is the measured 11.0, taken from the export trie rather than from that annotation.

So a band of 9.0 to 10.3.4 that linked a class implementation of this name would hold **two** classes
of one name in every process, and the runtime keeps the one it registered first - the release's - so
a lookup answered one of the two and the program holding the port's symbol held the other. The name
is therefore an alias through `charon_alias.h` (`MDLMeshBuffer11.m`), which is what
`modules/apple/backports.lua`'s own `check_categories` asks for when it reads this reading ("the
release carries MDLMeshBufferZoneDefault in ModelIO without exporting it: alias it through
charon_alias.h"), and what `NSTextList` and `NSTextTab` already are for the same one - UIFoundation
carries `NSTextList` from 6.0 and exports it from 9.0. The two members are a category on Charon's own
name, and the two values they hold are an associated object, because a category cannot add an
instance variable and neither can the class behind an alias: `attach.c` lays the proxy out from the
release's class and takes that write back when the two instance sizes differ.

What each band answers, and which of the three is measured where:

- **From 11.0** the release exports the name, so `band()` reexports the symbol and links neither the
  category's object nor the proxy: the release's own class answers. (release-split over this library's
  28 objects: `_OBJC_CLASS_$_MDLMeshBufferZoneDefault` and its metaclass first appear at 11.0.)
- **On 9.0 to 10.3.4** the release's class answers `-capacity` and `-allocator` and the category is
  not attached at all - `attach.c` adds a category method only where the class does not answer the
  selector - so a zone is Apple's own zone with Apple's own answers. Nothing in such a band makes one:
  `MDLMeshBuffer9.o` is out of those bands too (measured: `band()` reexports its three class symbols
  at 9.0).
- **Below 9.0** the release has no ModelIO, the proxy IS the class, and the category answers the
  capacity the allocator was asked to make.

Two things about the alias that are written down rather than left to be discovered, and
`charon_alias.h` says the first in its own comment: an application that asks the runtime for the name
with `NSClassFromString` gets nil on a release that has no class of the name, where the port's own
class answered before - the name belongs to a class of Charon's own there. And the proxy adopts
`MDLMeshBufferZone` from a `+load` (`class_addProtocol`), because `CHARON_ALIAS` declares the proxy
with a superclass and nothing else, and a category's protocol list belongs to the category: measured
with `otool -o` over a class with a category declaring `<P>`, `baseProtocols 0x0` on the class and
`count 1` on the category. Without that, `[zone conformsToProtocol:@protocol(MDLMeshBufferZone)]`
would answer NO on a band where it answered YES before, and on a release that carries the class the
macro's own `+conformsToProtocol:` answers the release's YES.

**Not measured**: none of this was run on a device. A zone Apple's own allocator hands out on 9.0 and
the port's zone below 9.0 are different objects by construction, and what a program that mixes the two
does with `-capacity` is a question about that program, not about this port.

What `attach.c` does with the proxy on each of those bands is why the middle one is safe, and it is
three different answers from one constructor:

- **Below 9.0** `objc_getClass("MDLMeshBufferZoneDefault")` answers nil, so the constructor skips
  this alias entirely: the proxy is not re-parented, nothing is adopted into anything, and its own
  `-capacity`, `-allocator` and `charon_setCapacity:allocator:` are what answer.
- **On 9.0 to 10.3.4** the release's class is found, so the proxy is re-parented under it, and the
  proxy's own copies of `-capacity` and `-allocator` are replaced by the release's implementations -
  `charon_adopt_methods` does that wherever the release's class already has the selector, so that a
  subclass of the proxy gets the release's answer. The proxy's own **class** methods are not: that
  call passes NSObject's own class as the "already has it" reference, so every one of the alias's
  class methods keeps the alias's answer, and `+alloc` keeps handing out
  `[objc_getClass("MDLMeshBufferZoneDefault") alloc]`, which is Apple's own class. That is what closes
  the hole the instance-method replacement would otherwise open: on such a band nothing can hold a
  proxy instance, so nothing can send Apple's `-capacity` to a proxy whose Apple ivars were never
  written.
- **From 11.0** neither object is in the band.

## What is measured, and what is reasoned

- **Measured**: that iOS 6 carries no ModelIO (the release's own selector table and dyld cache, read
  directly). That the port's own code is what answers every row below 7.0 - the gate builds it and
  reads the built libraries' exports and Objective-C metadata.
- **The fixtures are measured, not assumed.** The polygon file carries a `#` comment after
  `end_header` now, because that is legal PLY and what real writers emit, and the reader used to read
  the body as one flat token stream: every word of the comment was consumed as a coordinate and the
  asset came back empty with no error anywhere. It is read a line at a time with `#` lines skipped,
  exactly as the header's `comment` lines are, and the run above has both sides at one object and four
  vertices with the same box. The scene description is a `def Mesh` **with braces** - the first fixture
  had none, so the system read zero objects out of it, the two sides agreed on nothing, and the reader
  was never measured at all. The fixture now reads on the system as one `MDLMesh "Plate"` of five
  vertices, and the port reads one object of the same name and the same five vertices.
- **The one-sided lines.** Most are the per-vertex lines of a mesh the two sides built with a
  different number of vertices, so they follow from the counts already named; the rest are the naming
  and the material lines listed above. **No one-sided line is a port feature the system lacks.**
- **Still different, five measurements**: the tessellation counts of the ellipsoid and the cylinder, the
  descriptor of a mesh built from buffers, and the scene description's box, where the port reads a
  maximum of zero in Z for a point the file puts at one. The voxel extent is a named difference, not a
  rule to copy - the system's own answer is `INT_MAX` for small arrays and zero for larger ones, the
  same on every run, so it carries no information about the division.

## Where the boundary of this pass is

Not carried: `MDLCamera`, `MDLLight` and its three kinds, `MDLTexture`'s sky cube, the scattering
functions' property graph beyond what is here, `MDLMesh`'s subdivision, tangent basis, unwrapped
texture coordinates, ambient-occlusion and light-map baking, `MDLMesh`'s icosahedron, hemisphere and
capsule generators, `MDLVoxelArray`'s coarse mesh and signed-shell conversion beyond the shell
itself, and the six `kUTType*` constants of `MDLTypes.h`, whose string values are not in any cache
held here and were therefore left alone rather than guessed.
