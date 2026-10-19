# The fifteen vertex-attribute names, in the library that is always linked

15 rows, `registry/ModelIO/vertexattributes9.json`.

They arrived with iOS 9 and they are exported **data** symbols, which is the whole trouble. A band at
iOS 9 or later finds them in the release and drops the port's copy; the 6.1.3 band has no ModelIO at
all and needs the port's. So the symbol has to live in a library that is always linked — `ModelIO`'s,
which is where they are defined now — and `MetalKit`'s copy, which carried them for the vertex-descriptor
bridge, asks for them there. `libModelIOBackports.dylib` referenced them before this and the gate's
link said so:

```
Undefined symbols for architecture armv7:
  "_MDLVertexAttributeNormal", referenced from:
      _CharonMDLBuildMesh in MDLAsset9.o
```

Every value is the one the host's own symbol holds: `position`, `normal`, `textureCoordinate`,
`tangent`, `bitangent`, `binormal`, `color`, `jointIndices`, `jointWeights`, `occlusionValue`,
`edgeCrease`, `anisotropy`, `shadingBasisU`, `shadingBasisV`, `subdivisionStencil`.
