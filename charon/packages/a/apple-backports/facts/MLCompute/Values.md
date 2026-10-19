# What MLCompute is made of, and where each answer came from

MLCompute.framework of iOS 14 and macOS 11, in the version the newest SDK still declares
(SDK 16.4, which is what this port builds against; the corpus of SDK 26.2 names the same
seventy-eight classes and members for this framework, and its 26.2 headers dropped four of the
factories of iOS 14, which is written down below). Nothing here is a retyping of Apple's headers:
the declarations an application compiles against are Apple's, read from the SDK, and only the
behaviour is the port's.

This file is the reasoning behind the answers the registry gives, and the other five files in this
directory are the measurement behind each family:

| File | What it covers |
| --- | --- |
| `Values.md` | the thirteen functions of `MLCTypes.h`, `MLCPlatform` and the values of the enumerations |
| `Tensors.md` | `MLCTensorDescriptor`, `MLCTensorData`, `MLCTensorOptimizerDeviceData`, `MLCTensor`, `MLCTensorParameter` |
| `Device.md` | `MLCDevice`, and what a machine with no GPU and no Neural Engine answers |
| `Layer.md` | `MLCLayer`, the number a layer has before it is in a graph, and `+supportsDataType:onDevice:` |
| `Descriptors.md` | the ten descriptor classes, and the two host defects the port keeps |
| `Layers.md` | the thirty layer classes: their factories, measured, and **not carried** - the next family |
| `Engine.md` | what the framework computes, measured: the activations, the arity of every arithmetic operation, the constant a comparison writes, the shape-moving and reducing layers - **not carried** |

## The mutation, and why the script no longer carries one

The excuse list once named six patterns, of which three were answered the same way by both sides, and a
mutation proved the difference: +[MLCDevice cpuDevice] was made to report the wrong type, a case the port
*has* and which was excused because the list was too wide, and the check passed it. The list is now the
three that really differ - the GPU device, the Neural Engine, and a device asked for by type - and a case
the port has is no longer excused by anything, so the mutation cannot pass and the script does not carry
it. What it proved is kept here: the check reads the port's code, and the width of the list was the only
thing that could have hidden a divergence.

## How each answer was measured

Every value in this delivery was read off the host's own MLCompute, on macOS, through Mac
Catalyst, by asking it and writing down what it said. `tests/backports/host/mlcompute` is that
measurement turned into a check: one program of 377 cases, compiled once beside the framework and
once beside the port's four translation units with every name they define renamed, and the two
runs compared line by line. `sh tests/backports/host/mlcompute/run.sh` runs it.

Three cases are meant to differ and run.sh says so every time: `+[MLCDevice gpuDevice]`,
`+[MLCDevice aneDevice]` and `+[MLCDevice deviceWithType:MLCDeviceTypeGPU]`. The host has a Metal
device and a Neural Engine; iOS 6.1.3 has neither, and each side answers as a machine with what it
has. `Device.md` has the table.

## What is not carried in this delivery

The framework is delivered in three families, and this is the first: everything MLCompute is *built
out of* - the tensors, the device, the layer base, the ten descriptors and the functions that name
an enumeration's cases. 248 of the corpus's 564 missing rows for this framework.

The other two are the layers with the arithmetic behind them - thirty classes, 218 rows - and the
graphs, the optimizers and the training that drive them - 98 rows. Neither is in this delivery and
neither has a registry entry, which is on purpose: the registry answers what the package *carries*,
and an entry for a class the library does not define would stop the build. What those two families
are is the checklist's own, at `coordination/corpus/ledger/MLCompute.tsv`: every row whose class is
one of the thirty layer classes, and every row whose class is `MLCGraph`, `MLCInferenceGraph`,
`MLCTrainingGraph`, `MLCOptimizer`, `MLCSGDOptimizer`, `MLCAdamOptimizer` or `MLCAdamWOptimizer`.

Three factories of iOS 14 are not in the 26.2 headers and are not carried:
`+[MLCTensorDescriptor descriptorWithShape:]` with only a shape, and
`+[MLCTensor tensorWithShape:fillWithData:]` and `+[MLCTensor tensorWithShape:data:]` with only a
shape. The corpus of SDK 26.2 does not name them, the host's framework raises
`NSInvalidArgumentException` for the descriptor one when it is reached through the runtime
(measured) and does not answer the other two at all (measured: `+[MLCTensor respondsToSelector:]` is
NO for both), so there is nothing to carry and nothing a program of the corpus can reach. The
two-argument `+[MLCTensorDescriptor descriptorWithShape:dataType:]` that iOS 14 declared beside
`descriptorWithShape:` is in the corpus, is carried, and is what the differential compares.

`MLCRMSPropOptimizer` was in iOS 14 and is in neither the corpus of SDK 26.2 nor the current
headers: the framework took it away, and the registry says so with a `removed` entry rather than
backporting an API that modern iOS no longer has.

## The enumerations

A case of an enumeration is a value the compiler writes into the program. There is no symbol for
it at run time, so the registry gives it no entry - the rule is in `registry/README.md` - and the
values are the ones Apple's own headers carry, read from the SDK this port builds against. The
fourteen cases of iOS 14.5 and 15.0 that the corpus asks about are
`MLCActivationTypeHardSwish`, `MLCActivationTypeClamp`,
`MLCArithmeticOperationMultiplyNoNaN`, `MLCArithmeticOperationDivideNoNaN`,
`MLCArithmeticOperationMin`, `MLCArithmeticOperationMax`, `MLCReductionTypeL1Norm`,
`MLCReductionTypeAny`, `MLCReductionTypeAll`, `MLCDataTypeFloat16`, `MLCDataTypeInt8`,
`MLCDataTypeUInt8`, `MLCDeviceTypeANE` and `MLCExecutionOptionsPerLayerProfiling`. They compile
for 6.1.3 against the port's headers, which is what the ledger's `header-ok` says, and no
change is owed for them: the generator's rule lowers `API_AVAILABLE(ios(15.0))` to the target, so a case the
newest header declares is declared for this release too.
