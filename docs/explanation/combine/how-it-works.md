# How it works

Combine is not a fork. The code is OpenCombine's, pinned at one upstream commit; what is
ours is the patch series in `packages/c/combine/patches/`, applied by the `revenant@combine`
recipe in `packages/c/combine/`, and the targets of this module that build
the patched sources inside revenant.

The recipe fetches OpenCombine at its pinned commit and applies the patches in order. The
patches carry only content edits. Putting the three upstream modules together is the build's
work: the recipe installs the patched sources as one tree in the package's install folder (the paths below are inside it), `src/Combine` holding
`Sources/OpenCombine` with `OpenCombineDispatch` under `Schedulers/` and `OpenCombineFoundation`
under `Foundation/` (less the helper files the core already has under the same name),
`src/CombineHelpers` holding the C++ helper `COpenCombineHelpers`, `src/Tests` holding
upstream's tests and `src/utils` the header of its gyb templates.

There are two ways to take it:

- `revenant@combine` as it is: the recipe compiles that tree against
  `revenant@swift-runtime` and installs `libCombine.a`, `libCombineHelpers.a` and
  the `Combine` module.
- `revenant@combine` with `sources = true`: the recipe installs only the tree, and
  the project compiles it. This is what revenant does.
