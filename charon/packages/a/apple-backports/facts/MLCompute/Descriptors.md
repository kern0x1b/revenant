# The ten descriptors, and the two host defects the port keeps

Every default, every refusal and every array order below was measured on the host's own MLCompute
and is held to it case by case by `tests/backports/host/mlcompute`, which asks each factory of each
class with the arguments that matter and prints what came back.

## The way an argument array is read

`kernelSizes`, `strides`, `dilationRates` and `paddingSizes` are read with the **second** entry as
the x of the name and the first as the y, and a one-entry array is that value for both:

| Passed | Answered |
| --- | --- |
| `kernelSizes:@[@3, @5]` | `kernelWidth` 5, `kernelHeight` 3 |
| `strides:@[@2, @1]` | `strideInX` 1, `strideInY` 2 |
| `dilationRates:@[@1, @3]` | `dilationRateInX` 3, `dilationRateInY` 1 |
| `paddingSizes:@[@4, @2]` | `paddingSizeInX` 2, `paddingSizeInY` 4 |

A missing array is one for a kernel, a stride and a dilation, and **zero** for the two padding
sizes: a convolution with `MLCPaddingPolicySame` and no padding sizes answers 0 by 0, and so does a
max pooling, an average pooling and an L2-norm pooling with none.

## What the shorter factories keep

Every factory that takes fewer arguments than the longest form of its class keeps the longest
form's default for what it does not carry, and the defaults are not all one:

| Class | Shorter form | What it keeps |
| --- | --- | --- |
| `MLCActivationDescriptor` | `descriptorWithType:`, `:a:`, `:a:b:` | per type, below |
| `MLCLossDescriptor` | `descriptorWithType:reductionType:` | weight 1, label smoothing 0, one class, epsilon 1e-7, delta 1 |
| `MLCLossDescriptor` | `...weight:` | label smoothing 0, one class, epsilon 1e-7, delta 1 |
| `MLCOptimizerDescriptor` | the four-argument form | no clipping, by value, clip 1 and -1, maximum norm 1, custom global norm 1 |
| `MLCLSTMDescriptor` | the three-argument form | biases, batch first, returns sequences, no dropout, the output result mode |
| `MLCMultiheadAttentionDescriptor` | `descriptorWithModelDimension:headCount:` | the key and the value take the model's own dimension, biases, no attention bias, no zero attention, no dropout |
| `MLCEmbeddingDescriptor` | `descriptorWithEmbeddingCount:embeddingDimension:` | no padding index, no maximum norm, a p-norm of **2**, no frequency scaling |
| `MLCMatMulDescriptor` | `descriptor` | a scale of 1, no transposition |
| `MLCPoolingDescriptor` | `poolingDescriptorWithType:kernelSize:stride:` | a stride of the kernel, a dilation of one, the same padding policy, no padding size, no padding in the count |
| `MLCConvolutionDescriptor` | `descriptorWithKernelWidth:kernelHeight:in:out:` | a standard convolution, one group, a stride and a dilation of one, the same padding policy, no padding size |

The activation defaults are one for a, b and c, and four types differ: **ReLU** has a of 0,
**linear** a b of 0, the **hard sigmoid** an a of 0.2 and a b of 0.5, and the **hard shrink** and
the **soft shrink** an a of 0.5. Every other type, including the ReLUN, the tanh shrink and the
GELU, carries 1, 1, 1 - the values `+[MLCActivationLayer relu6Layer]`, `+tanhShrinkLayer` and
`+geluLayer` answer are the *layer's*, not the descriptor's default, and belong to the layers family.

## The initialisers the header marks unavailable

All sixteen of them are carried, because a program finds them however the header is spelled. What
each answers, measured:

| Class | Answer |
| --- | --- |
| `MLCTensorDescriptor` | no dimensions, no shape, the invalid data type |
| `MLCTensorData` | a length of 0 |
| `MLCTensorOptimizerDeviceData` | a live object with nothing of its own |
| `MLCTensor` | no descriptor, no data, no name, the number 0 |
| `MLCTensorParameter` | no tensor, not updatable |
| `MLCLayer` | the number 0, no name, not debugging |
| `MLCActivationDescriptor` | the identity activation, a, b and c of 0 |
| `MLCConvolutionDescriptor` | a standard 1 by 1 convolution from one channel to one, one group, a stride and a dilation of 1, the same padding policy and no padding size |
| `MLCPoolingDescriptor` | everything zero, and a pooling type of 0 which is not one of the three the framework names |
| `MLCLossDescriptor` | the mean absolute error, no reduction, every parameter 0 |
| `MLCOptimizerDescriptor` | every number 0, no clipping, no regularization |
| `MLCMatMulDescriptor` | a scale of 0, no transposition |
| `MLCEmbeddingDescriptor` | nothing set at all, not even the number of rows |
| `MLCLSTMDescriptor` | everything zero and the output result mode |
| `MLCMultiheadAttentionDescriptor` | everything zero |
| `MLCYOLOLossDescriptor` | no anchor boxes, a count of 0, every scale 0 and no rescore |

## The YOLO loss descriptor's own numbers

`+descriptorWithAnchorBoxes:anchorBoxCount:` carries the scales the YOLO loss itself runs with, and
these are measured: a rescore of **yes**, 10 for the spatial position, 10 for the spatial size, 5
for the confidence that no object is there, 100 for the confidence that one is, 2 for the class, an
intersection over union of **0.7** for an object to be there and **0.3** for it to be absent. All
seven are readwrite, and a program that sets them reads its own values back.

## Two defects of the host that the port keeps

Both are measured, both are visible in the differential, and the port reproduces them rather than
being quietly better than the framework it stands for - a port that answered differently here would
be a difference no test of the framework would ever find, and would be a silent one.

1. **`-[MLCMatMulDescriptor copyWithZone:]` loses both transpositions.** A descriptor with a scale
   of 2 and `transposesX` set copies to a scale of 2 and no transposition. The port's copy does the
   same.
2. **`-[MLCYOLOLossDescriptor copyWithZone:]` discards the scales that were set.** A descriptor
   whose class scale was set to 5.5 and whose intersection-over-union was set to 0.75 and 0.85
   copies to the loss's own numbers again - 2, 0.7 and 0.3 - and keeps only the anchor boxes and
   their count. The port's copy does the same.

Both are one line each in `MLCDescriptors14.m`, and both are cases in the differential so that a
future release of the framework that fixes them will show up as a difference rather than pass in
silence.
