# The tensors: what a tensor of this port is made of, and every answer measured

All of it read off the host's own MLCompute on macOS through Mac Catalyst, and held to it case by
case by `tests/backports/host/mlcompute` - 377 cases, of which the tensor family is about two
hundred. What is below is what the measurements settled; nothing here is reasoned from the
header's comments.

## The shape of a tensor

A shape is reported with the batch dimension first and the width last, each dimension varying
faster than the one before it, and the stride is in bytes:

| Asked for | `shape` | `stride`, float32 |
| --- | --- | --- |
| `descriptorWithShape:@[@2,@3,@4,@5] dataType:float32` | 2, 3, 4, 5 | 240, 80, 20, 4 |
| `descriptorWithWidth:5 height:6 featureChannelCount:7 batchSize:8` | 8, 7, 6, 5 | 840, 120, 20, 4 |
| `convolutionWeightsDescriptorWithWidth:3 height:3 in:4 out:5` | 1, 20, 3, 3 | 720, 36, 12, 4 |
| `convolutionWeightsDescriptorWithInputFeatureChannelCount:4 outputFeatureChannelCount:5` | 1, 20, 1, 1 | |
| `convolutionBiasesDescriptorWithFeatureChannelCount:5` | 1, 5, 1, 1 | |

So the first entry of a shape is the outermost dimension, and the last is the width. The weights
of a convolution are one image whose channels are the output times the input, which is what the
framework's own weights descriptors produce and what a convolution layer of this port reads.

`+[MLCTensorDescriptor maxTensorDimensions]` is **4**, measured.

## What a descriptor refuses

| Asked for | Answer |
| --- | --- |
| more than four dimensions | nil |
| an empty shape | raises `NSRangeException` |
| a shape with a zero in it | nil |
| `MLCDataTypeInvalid`, the value 2, `MLCDataTypeCount` | nil |
| every other data type | a descriptor, of this size per element |

The exception is the framework's own: it reads the first dimension of the shape it is given and
raises when there is none, so the port raises the same `NSRangeException` with the same text rather
than inventing a descriptor of a shape nothing described. The data types with no storage are
`MLCDataTypeInvalid`, the value 2 (which is not one of the enumerated cases) and
`MLCDataTypeCount`; the two values between the enumerated ones that are neither - 2 and 6 - are not
the same, and the framework gives one byte for the second of them and nothing for the first. The
sizes are 4, 2, 1, 8, 4, 1 and 1 bytes for float32, float16, boolean, int64, int32, int8 and
uint8.

`+[MLCTensorDescriptor descriptorWithShape:sequenceLengths:sortedSequences:dataType:]` answers
**nil** for every pair of arguments tried - (4, 4) with the lengths 3, 2, 1, (3, 2) with 3, 2, 1,
(2, 4) with 2, 1 and (4, 2) with 4, 3, 1 all give nil - and never a descriptor. The port answers
the same, and the sequence tensors are built by the port's own path instead, whose answers *were*
measured:

| Asked for | `shape` | `sequenceLengths` | `batchSizePerSequenceStep` |
| --- | --- | --- | --- |
| `tensorWithSequenceLengths:@[@3,@2,@1] sortedSequences:YES featureChannelCount:2 batchSize:1` | 1, 3, 2 | 3, 2, 1 | 3, 2, 1 |
| `tensorWithSequenceLength:3 featureChannelCount:2 batchSize:2` | 2, 3, 2 | 3, 3 | 2, 2, 2 |

`batchSizePerSequenceStep` is the sequence lengths themselves, not a count of the sequences still
running at each step. The shape is the batch, the longest sequence and the feature channels, and
the plain form fills the tensor with random values while the form that is given a nil data object
does not.

## The data of a tensor

`data` is the whole buffer the tensor was given, larger than the tensor or not: a tensor of four
floats given a sixty-four float buffer reports sixty-four, and a tensor given eight bytes reports
eight. The port copies the bytes rather than holding the caller's buffer, which the header permits
(it asks the caller to keep its memory alive, and a copy needs nothing of it) and which keeps a
caller that passed a buffer it did not allocate with `malloc` - a tensor on the stack, as a test
does - from being written through later.

A tensor with no data answers a nil `data`, YES to `-hasValidNumerics`, YES to `-synchronizeData`
and to `-synchronizeOptimizerData`, NO to `-copyDataFromDeviceMemoryToBytes:length:synchronizeWithDevice:`
and NO to `-bindAndWriteData:toDevice:`. The CPU device computes into the memory a program reads,
so there is nothing to bring back and the two synchronization calls cannot fail.

The name a tensor is given when nothing names it is `data` and its number, counting from zero in
the order the factories made them (measured: the first is `data0`). A tensor made by
`-initWithZone:`-style initialisation - `+[MLCTensor new]`, which the header marks unavailable -
has no descriptor, no data, no name and the number zero whatever has been made before it. A copy
takes a number of its own and the name that goes with it, keeps the descriptor, the data and the
optimizer data, and does not keep the device.

## The random initializers

Measured over two million values each. The framework's generator is not published, so the *stream*
of values is the port's own; what is held to the framework is what a program can rely on - the
range each initializer covers, and that the seed decides it.

| Initializer | Framework | Port |
| --- | --- | --- |
| `Uniform` | 0 to 1, mean 0.501, standard deviation 0.289 | the same range and mean |
| `GlorotUniform` | -sqrt(3) to +sqrt(3) exactly, mean 0.0007, standard deviation 0.9998 | the same bound |
| `Xavier` | a normal draw of standard deviation one half: mean 0.0005, standard deviation 0.5000, and no bound at all - over two million values it reached -2.28 and 2.75 | the same mean and deviation |

The bound of Glorot and Xavier does not follow the fan-in and the fan-out of the tensor: a 4 by 4
and a 64 by 64 both fill the same range, and the port does not make the bound depend on the shape
either. With no seed set the values repeat from one initializer to the next, and setting the same
seed twice gives the same values while another seed gives others - both measured, and both true of
the port's generator, which is a 64-bit xorshift of the port's own: no library, the same on every
machine, and its whole state is the seed. The port's normal draw is Box and Muller's polar form
(1963), which needs no table.

## Quantization

`-[MLCTensor tensorByQuantizingToType:scale:bias:]` and its per-axis form, and the two
dequantizing ones, answer a tensor of the data type asked for whose storage is **all zero** -
whatever the scale, the bias, the axis and the values of the tensor are. Measured for float32
values from 0 to 4, for uint8, int8 and int32, for scales of 0.5 and 2, for biases of -1, 0 and 1,
and for the per-axis form with the scale and the bias in tensors of their own: every element zero
every time. The framework's CPU path allocates the storage of the narrower type and leaves it for a
graph to fill, because the scale and the bias are the graph's parameters and take effect when it
is compiled with them bound to the tensor.

The port answers the same and does not apply the scale itself. It is written down here rather than
left to be discovered: a program that quantizes a tensor outside a graph gets zeros from the
framework and zeros from the port, and the graph that fills them is the training family, which is
not in this delivery. The dequantizing forms answer a float32 tensor of zeroed storage, and
`tensorByDequantizingToType:` with any other data type answers nil, as the framework does.

The two forms that are asked about with a data type that is not a quantized one - float32, or
float16 - answer nil, as the framework does.
