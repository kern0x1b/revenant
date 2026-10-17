# The writer of a Core ML model container, round-tripped against the host

`CoreML/CharonMLWrite.c` encodes the document the reader keeps for an opened model (`CharonMLModel.c` keeps it as
`model->document`) back to the protocol buffer wire format, which is the `.mlmodel` container. It is measured by
`tests/backports/host/coreml-writer`.

## What the test measures

- Two system models of the TuriCore framework (`maml-video-light.mlmodel`, 595 359 bytes, and `resnet-16.mlmodel`,
  6 742 509 bytes): read with the port's reader, written with the port's writer, the written bytes are compared with
  the originals. Both are byte for byte the original.
- The host loads each written file (its compiler accepts it), and describes its inputs and outputs as it describes the
  original. Both descriptions are equal.

## What the writer keeps and what it drops

- Field order is the reader's order. The reader keeps the fields in the order the wire carries them, so a file the
  writer produced from a document the reader built is the file again.
- A packed run is written as a run: consecutive elements of one field go back out under one tag and one length.
- A field the specification does not declare is dropped by the reader (it steps over it and keeps no trace), so the
  writer does not write it. This matters only for a file from a later specification version.
- The writer refuses a document that is not a message.

## What the writer does not do

- The writer is the port's encoder for a container. The protocol MLWritable, which adopts `-writeToURL:error:`, is not
  on any object yet: on the host the protocol is adopted by `MLWritableWrappedModel`, the class an update's result
  is, so the conformance comes with the update loop (registry row MLWritable, facts/CoreML/Update13.md).
