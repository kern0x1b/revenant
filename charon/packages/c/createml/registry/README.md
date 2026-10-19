# What this registry is for, and why it is not in `apple-backports/registry/`

`apple-backports/registry/` describes what the **backports libraries export**. `check_registry`
(`modules/apple/backports.lua`) reads it after every build and fails on an entry that says
`implemented` and names nothing the built dylibs export — with one exception, a protocol or a member
of one, which is never counted as unbuilt.

Every name in *this* directory is a Swift type of a module in **this** package, and a Swift module
exports no symbol a dylib inventory sees. So an entry for one of them in `apple-backports/registry/`
is not a record, it is a false claim: it says the backports library carries a type it does not. The
first build with those entries there said so by name — 51 of them, in one line:

    error: the registry does not describe what the backports carry:
      listed as implemented, but nothing of that name is built: AnnotatedFeature ... MLShapedArray ...

which is the check being right and the placement being wrong.

So the record of what this package implements lives here, beside the code it describes, and
`apple-backports/registry/` keeps **one** thing: `MLMultiArrayDataType` and its six cases. That one
has to be there, because the generator's rule (`tools/gen/target_availability.lua`) reads the backports
registry for what to lower, and this registry file is the only thing that brings CoreML's headers into the
port's headers. It is a
header-only enumeration, so nothing is built for it, and `check_registry` will still name it; that
single name is the whole of the outstanding blocker and it is in the delivery.

The files:

| file | what it records |
| --- | --- |
| `TabularData.json` | `DataFrame` and its columns |
| `CreateMLComponents-linear.json` | the linear and logistic models, their protocols and their errors |
| `CreateMLComponents-transformers.json` | the eight feature transformers and `ColumnarTransformer` |
| `CoreML.json` | the shaped-array overlay: `MLShapedArray`, `MLShapedArraySlice`, `MLShapedArrayScalar` |

Each entry carries a `facts` file under `apple-backports/facts/`, which is where the measurements
live and where a reader is sent for the why.
