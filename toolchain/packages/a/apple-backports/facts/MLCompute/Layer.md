# MLCLayer, the base of the thirty layers

Everything here was measured on the host and is held to it case by case by
`tests/backports/host/mlcompute`. Three answers are worth writing down because they are the ones a
program reads and none of them is the obvious one.

## The number a layer has

`layerID` is **0** for every layer that is not in a graph, and does not increase: the layers of a
program that were never added to a graph all answer 0, measured for every layer class. The number a
layer has inside a graph is its position in that graph, counting from 1, which is the numbering the
framework's own DOT description prints. So the counter is the graph's, and the port keeps a layer at
0 until a graph gives it a number.

## The name a layer is given

`label` is **nil** until one of the layer's factories names it. Measured: an initialised layer of
every one of the twenty-three layer classes answers nil, and the factories name them - the selection
layer "Selection", the activation layer "Activation", the arithmetic layer "Arithmetic", the
concatenation layer "Concat", the loss layer "Loss" (measured, and the set is in the differential's
cases, which the layers family will extend).

## Which device a layer runs on, and what data types it supports

`deviceType` answers **2147483647** before a graph is compiled - the count of the enumeration
rather than a type in it, which is what a program that asks too early gets (measured). The port
answers the same rather than a plausible-looking zero, because a program that reads zero and
compares it against `MLCDeviceTypeCPU` would then believe the layer is on the CPU before anything
said so.

`+[MLCLayer supportsDataType:onDevice:]` answers **NO for every data type and every device**,
measured for all nine of the data types on the CPU, for a nil device, and on the host's own Metal
device. That is the framework's own answer rather than a refusal to try, and the port gives it,
because a program that asks first has to be prepared for NO on the host too. The layers that need
to know can answer for themselves, which is what `MLCLayer.deviceType` is for once a graph is
compiled.
