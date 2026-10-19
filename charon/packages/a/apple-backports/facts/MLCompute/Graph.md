# MLCompute's graph: a node, and what a node answers

Measured on this host's own MLCompute, macOS 27.0 build 26A428 (M4 Pro), by
`.agent-work/runs/probe/mlc-graph.m`, and held to again by `tests/backports/host/mlcompute/graph-cases.m`,
which compiles `MLCGraph14.m` beside the port's other six objects and beside the framework and compares the
two runs. Nothing here is read out of a header comment: where the header says nothing, the run is what
decided.

## The device is nil, and a bind does not change that

`+[MLCGraph graph].device` is nil on a graph nothing has been added to, and it is nil again on a graph that
`bindAndWriteData:forInputs:toDevice:synchronous:` has just been given the CPU device. So the device a
graph runs on is set by a compile, and this port's is nil until one. The property is not "the CPU device by
default": measured, it is nil.

## A node's result, and a layer that cannot take the sources it was given

| what was asked | what the host answers |
| --- | --- |
| `nodeWithLayer:source:` over a ReLU and a 2x3 tensor | a 2x3 `MLCDataTypeFloat32` tensor |
| `nodeWithLayer:sources:` over the same layer and two tensors | **nil** |
| `nodeWithLayer:sources:` over three tensors | **nil** |
| `nodeWithLayer:sources:disableUpdate:YES` over two | **nil** |
| `nodeWithLayer:sources:lossLabels:` over two | **nil** |
| `graph.layers` before any node, and after those five | `0`, and **`1`** |

So a node is one layer, one source, one result, and a layer that takes more sources than it has answers nil
rather than a tensor of a guessed shape. And `layers` holds each layer **once**: five nodes made over one
ReLU answer a graph with one layer in it. `sourceTensorsForLayer:` and `resultTensorsForLayer:` answer one
tensor each for that layer, and an empty array for a layer no node uses.

## The shape operations do not check, and one of them refuses

| what was asked over a 2x3 float32 tensor | what the host answers |
| --- | --- |
| `concatenateWithSources:@[a, b] dimension:1` | 2x6 |
| `concatenateWithSources:@[a, b] dimension:0` | 4x3 |
| `concatenateWithSources:@[a, b] dimension:3` | **an `NSRangeException`**, from `-[MLCConcatenationLayer resultTensorFromSources:]` indexing the sources with the dimension |
| `reshapeWithShape:@[@6]` / `@[@3, @2]` | 6, and 3x2 |
| `reshapeWithShape:@[@7]` over six elements | **a 7-element tensor** - the graph does not check the count |
| `reshapeWithShape:nil` | **an `NSRangeException`**: `+[MLCTensorDescriptor descriptorWithShape:stride:dataType:]` reaches `-[__NSArray0 objectAtIndex:]` |
| `transposeWithDimensions:@[@0, @1]` / `@[@1, @0]` | 2x3, and 3x2 |
| `transposeWithDimensions:@[@0]` over a rank-2 tensor | **nil** |
| `transposeWithDimensions:@[@0, @2, @1]` over 2x3x4 | 2x4x3 |

A permutation that is not a permutation of the rank is nil; a shape the caller asked for is the shape the
caller gets. The two exceptions are recorded and not asked, because a probe that raises is a probe that
stops - and the harness's cases would stop with it.

## A split

| what was asked over a 2x3 tensor | what the host answers |
| --- | --- |
| `splitWithSource:splitCount:2 dimension:1` | two tensors, **2x2** and **2x1** |
| `splitWithSource:splitCount:3 dimension:0` (extent 2) | **two** tensors, 1x3 and 1x3 |
| `splitWithSource:splitSectionLengths:@[@1, @5] dimension:1` (extent 3) | two tensors, **2x1** and **2x5** |
| `splitWithSource:splitCount:2 dimension:1` over 2x3x4 | two tensors, 2x2x4 and 2x1x4 |

Two rules, both measured and both counter-intuitive enough to be worth stating: **the remainder goes to
the first part** (an extent of 3 into two gives 2 then 1, not 1 then 2), and **the count is capped at the
extent** (an extent of 2 into three gives two parts, not three and not an error). The section lengths are
not checked against the extent either: lengths summing to six over an extent of three answer extents of one
and five.

## What a bind answers

| what was asked | what the host answers |
| --- | --- |
| `bindAndWriteData:forInputs:toDevice:synchronous:` with a name the graph never knew | **YES** |
| the same with an empty dictionary on both sides | **YES** |
| the same with `forInputs:` nil | **NO** |
| `graph.device` straight afterwards | **nil** |

So what decides it is whether the caller's inputs are there at all, not whether every name resolves, and a
bind does not give the graph its device.

## `summarizedDOTDescription`, character for character

```digraph MLCGraph {
 node [style=filled];
}
```

42 characters on this host, with nodes in the graph and without. The nodes are not in it: the host's is a
summary, and this is the summary.

## The two raises, recorded and not asked

* `concatenateWithSources:dimension:` with a dimension at or past the rank is an `NSRangeException` inside
  `-[MLCConcatenationLayer resultTensorFromSources:]`, which indexes the sources array with the dimension.
* `reshapeWithShape:` with a nil or empty shape is an `NSRangeException` inside
  `+[MLCTensorDescriptor descriptorWithShape:stride:dataType:]`, reached through
  `-[MLCReshapeLayer resultTensorFromSources:]`.

A release that raises is a release that has no answer to compare, so the port's `nil` in those two places is
a difference of this port's own and not a match: they are named here rather than asked.

## The inference graph and the training graph, written, and held case by case

`MLCInferenceGraph` is `MLCompute/MLCInferenceGraph14.m` and `MLCTrainingGraph` is
`MLCompute/MLCTrainingGraph14.m`, each with its own dictionaries and its own methods and no category seam
between them; the two forms that arrived in 14.5 are the categories in `MLCompute/MLCGraphConstants15.m`,
because an object carries the API of one release. `tests/backports/host/mlcompute/inference-cases.m` asks
**every member of both classes** of the host's own MLCompute and of the port's, in one program beside the
other case files, and compares the two runs line by line.

The two classes inherit `-layers`, `-sourceTensorsForLayer:` and `-resultTensorsForLayer:` from MLCGraph and
answer them **over the graph objects they were made from**, which is the host's own answer and not
MLCGraph's:

| over one graph with one ReLU node on a 2x3 tensor | both classes answer |
| --- | --- |
| `layers` | **1** |
| `sourceTensorsForLayer:` for that layer | **1 tensor, `[2,3]` float32** |
| `resultTensorsForLayer:` for that layer | **1 tensor, `[2,3]` float32**, and it is the very tensor the node made |
| `device` before a compile | **nil** |
| `device` after a compile | **a device** |
| `summarizedDOTDescription` | **415 characters**, where MLCGraph's own summary is 42 - so the two classes are not asked for it: the row is MLCGraph's and its answer is the measured one |

## The three bindings the cases ask, and why each one

**The inference graph** over its own graph object, one node, rank-2 tensors, the CPU device, and the loss
label tensors declared before anything is executed. Measured over that binding:

| | the host answers |
| --- | --- |
| `+new` and `-init`, which their own headers mark unavailable | **an object** with no layer, no node, no optimizer and no device |
| `addInputs:`, over a name the graph knows, one it does not, an empty dictionary, nil | **YES** for all four |
| `addInputs:lossLabels:lossLabelWeights:` | **YES** |
| `addOutputs:`, known, unknown, nil | **YES** for all three |
| `linkWithGraphs:`, with an empty list, with itself, with another graph | **YES** for all three, and `layers` stays **1** and the results stay **one tensor**: a linked graph shares its tensors rather than joining this graph |
| `compileWithOptions:device:` with a device | **YES** |
| the same with **no** device, on a graph that has not been compiled | **NO** |
| the same with no device, on a graph that has | **YES** |
| `deviceMemorySize` before the compile / after | **0** / **24** |
| the 14.5 form, with nil dictionaries, two empty ones, tensors with no data, data with no tensors, both | **YES** for all five |
| the four execute forms | **YES** for all four, and an execute of a ReLU over -1, 2, -3 and 4 writes **0, 2, 0 and 4** into the buffer the caller named for the output and calls the completion handler with **no error** |

**The binding that decides the two loss forms is the loss labels themselves.** Measured: with the loss label
tensors *not* declared on the graph, `-executeWithInputsData:lossLabelsData:lossLabelWeightsData:batchSize:options:completionHandler:`
and the form that adds `outputsData:` answer **NO** while the two forms without loss labels answer YES; with
`-addInputs:lossLabels:lossLabelWeights:` called first, **all four answer YES**. That is what the header's own
comment asks a caller to do - "each input, loss label or label weights tensor is identified by a NSString ...
this NSString is used to identify which data object should be as input data" - and the cases declare them
before the four forms. A harness that asks the two loss forms without declaring the labels first is measuring
its own binding, not the member.

**The training graph** over **that same graph object, after the inference graph has compiled it**. That is
the binding every answer below was measured in, and the reason it is the one the cases use is in the next
section: over a graph object nothing has compiled, the host's training graph raises in its forward pass, so
no case can hold this port to any of its engine members there.

| over the graph object the inference graph compiled | the host answers |
| --- | --- |
| `optimizer` of a graph made without one / with one | **nil** / **kept** |
| `layers`, sources, results | **1**, **one tensor**, **one tensor** |
| `deviceMemorySize` before its compile / after | **0** / **24** |
| `addInputs:lossLabels:`, `addInputs:lossLabels:lossLabelWeights:`, `addOutputs:` | **YES** for all three |
| `linkWithGraphs:`, empty, itself, another | **NO** for all three |
| `compileWithOptions:device:` and the 14.5 form | **NO** for both |
| `compileOptimizer:` | **NO** |
| the seven execute forms | **NO** for every one |
| `gradientTensorForInput:`, for the input, for the graph's own result, for a tensor it never saw | **nil**, **nil**, **nil** |
| `sourceGradientTensorsForLayer:` for that layer / for a layer it never used | **1 tensor, `[2,3]` float32, and not the source itself** / **none** |
| `resultGradientTensorsForLayer:` | **none** |
| `gradientDataForParameter:layer:` and `allocateUserGradientForTensor:`, known and unknown | **nil** for all four |
| `stopGradientForTensors:`, `setTrainingTensorParameters:`, `bindOptimizerData:deviceData:withTensor:` | **YES** for all four |

**The third binding: what the port cannot be held to, and why.** Over a graph object **nothing** has
compiled, the host's training graph answers differently, and every one of those answers is measured
(`probes/mlc-training-forms.m`):

| over a fresh graph object of its own | the host answers |
| --- | --- |
| `compileWithOptions:device:` | **YES** |
| `deviceMemorySize` after it | **48**, twice the node's 24 - the forward pass and the gradient pass |
| `executeGradientWithBatchSize:options:completionHandler:` and `executeOptimizerUpdateWithOptions:completionHandler:` | **YES** for both |
| `executeForwardWithBatchSize:options:completionHandler:`, with and without `outputsData:` | **an NSRangeException**, "index 0 beyond bounds for empty array", inside the CPU engine |

So in that binding the host says YES to a gradient pass and to an optimizer update, and this port's engine
has neither: `facts/MLCompute/Engine.md` records that the engine carries the activations and nothing else. The
port's training graph therefore answers NO to every member that needs one of those two passes, which is what
the host answers in the binding the cases can ask, and the difference in the other binding is **named here
rather than hidden**. What the port *does* compute is the inference graph's forward pass, and the case for it
compares the bytes: an execute over a ReLU writes 0, 2, 0 and 4 on both sides.

## The raises, and which bindings cannot be asked at all

* **A graph with no layer cannot be compiled.** `[MLCInferenceGraph graphWithGraphObjects:@[]]` makes a graph
  with no layers, and `-compileWithOptions:device:` on it raises an `NSRangeException` - "index 0 beyond
  bounds for empty array" - inside the host's own code (`probes/mlc-inference-forms.m`). The 14.0 compile
  over a graph with one node does not raise; the 14.5 form raises only over the empty graph. So no case
  compiles a graph with no layer, and `+new`/`-init` are asked for the object they answer and nothing else.
* **`MLCExecutionOptionsSkipWritingInputDataToDevice` makes the plain execute form raise**, the same
  `NSRangeException` (`probes/mlc-raise.m`). The cases pass `MLCExecutionOptionsNone` or
  `MLCExecutionOptionsSynchronous`, and the synchronous option is what
  `tests/backports/host/mlcompute-engine/system.m` - the oracle for the numbers - passes as well.
* **A second node over a graph's own result raises**, `-[__PlaceholderDictionary initWithObjects:forKeys:count:]`,
  which is why every graph measured here has exactly one node and why the sum over several nodes is the one
  rule of the device-memory table that this measurement does not decide.
* **A layer that is already a node of another graph answers a nil node** when it is used in a second graph
  (`probes/mlc-inference-forms.m`), so the case that reads numbers out of an execute gives that graph a layer
  of its own. It is the framework's own bookkeeping about a layer belonging to one graph, and it is written
  here because the first version of the case file tripped over it and a reader will otherwise read the case as
  arbitrary.

## What is asked of the two classes, and what is left

Every member of both classes is a case in `tests/backports/host/mlcompute/inference-cases.m`, and the two
rows the two classes carry that the corpus of SDK 26.2 does not name - `+[MLCTrainingGraph new]` and
`-[MLCTrainingGraph init]` - are carried because the classes carry them, and the cases ask them the way
`tests/backports/host/mlcompute/cases.m` asks every unavailable initialiser: through the `Class`, since the
compiler refuses the name.

Not asked, and why: the two `summarizedDOTDescription` answers above (415 characters against MLCGraph's 42,
and the row is MLCGraph's); the framework's own first argument to a completion handler, which nothing reads
and which the port states in its own file; and the multi-node value of `deviceMemorySize`, which no binding
reaches without the raise above.

## `deviceMemorySize` over the bindings, and the rule taken back

Restored at landing from the previous version of this page, verbatim but for the line introducing the rules and the second rule, which the
measurement above took back (the third paragraph below, from the commit that took it back). This is the
device-memory table the multi-node rule above refers to.

**`deviceMemorySize` is pinned down, and it is none of the three hypotheses.**
`tests/backports/host/mlcompute/probes/device-memory.m` builds graphs where the input's bytes, the output's
bytes and a sum over both are three different numbers. Every operand in it is a tensor the probe makes, never
one a node made, because a graph's own result asked for as an output raised inside the host on the earlier
sweep. What this host answers, over a graph with a single node whose result holds six `MLCDataTypeFloat32`
elements - twenty-four bytes - and over one whose result holds one - four bytes:

| the graph | before a compile | after |
| --- | --- | --- |
| six elements, nothing bound | 0 | **24** |
| six elements, one input of six | 24 | **24** |
| six elements, one input of **one** | 24 | **24** |
| six elements, one output of six | 24 | **24** |
| six elements, an input of one **and** an output of six | 24 | **24** |
| six elements, two inputs of six | 24 | **24** |
| six elements, one input of six and **two** outputs of six | 24 | **24** |
| six elements, an input of one and outputs of six and one | 24 | **24** |
| **one element**, an input of one and an output of one | 0 | **4** |
| one element, nothing bound | 4 | **4** |
| one element, an input of six | 4 | **4** |
| one element, an input of six and an output of one | 4 | **4** |
| two graphs linked, one bound to an input of one and the other to six | 24 and 24 | **24 and 24** |

The rule that stands, measured (the second this page carried is taken back below; the "before a compile" column of 24 rows is what that taken-back rule was read from, and is not explained):

* **It is the byte width of a tensor the graph's OWN nodes produce.** The caller's bindings do not move it at
  all: an input of one element and an input of six over the same six-element graph are the same 24, two
  outputs of six are the same 24, and a graph whose node holds one element is 4 whatever is bound to it and
  whatever a link adds. So the input's bytes, the output's bytes and a sum over both are **all three refuted**.

**A rule this facts page carried and has taken back: "another graph in the same process".** It said
deviceMemorySize is 0 "until the graph has been compiled - or until another graph in the same process has
been", naming a third graph, made after two had compiled and never compiled itself, as answering 24 on its
first read. The training graph's own first read refutes the rule that sentence stated: with a compiled
inference graph beside it, it answers 0, and 24 only after its own compile has been asked - which answers NO.
What that third graph shared with the compiled ones is not recorded anywhere, so no lazy global of the
framework is claimed; what is measured is the per-graph rule, and the port implements that one.
