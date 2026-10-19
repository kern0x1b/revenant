# The Core ML model schema, vendored

These are **Apple's**, from `coremltools/mlmodel/format/` on
<https://github.com/apple/coremltools> — `Model.proto`, `FeatureTypes.proto`, `Parameters.proto`,
`DataStructures.proto`, `TreeEnsemble.proto` and `NeuralNetwork.proto`, with `LICENSE.txt` beside
them.

**The licence is BSD-3-Clause**, read out of the vendored `LICENSE.txt` itself and not from the
repository's label: three conditions, the third being that neither Apple nor any contributor may be
used to endorse or promote a derived product, and the closing "IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE" sentence. My first note on these files said Apache-2.0, which was wrong —
it was read off a licence line elsewhere in the tree rather than off this file, and the coordinator's
"as far as I know, BSD-3" was right.

**Pinned at `v3.0-beta`, commit `22088dd56d34a4da76122d36053e6bbcc69e424f`** (the tag `main` pointed at
when they were taken; `main` itself is `db4dd46b64dcaa4c636c8360b5485c18828140d8`). A copy of
`LICENSE.txt` is vendored so the terms travel with the files rather than being a claim about a
repository that can change.

They are here because a `.mlmodel` is a protobuf over this schema, and a port that writes one has to
write *this* schema, not a paraphrase of it. `Protobuf/Codec.swift` implements the **wire format**
and nothing else; every field number the model messages use is read out of these files, and the ones
the model writer emits are named after them.

Nothing is generated from them: this target has no protobuf compiler, and the messages a Core ML
model of these estimators needs are a small, fixed set. The schema is vendored so that a reader can
check every number against the definition it came from, and so that adding a field does not mean
guessing a number.
