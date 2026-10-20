# OpenCombine: third-party notice

MIT License

Copyright (c) 2019 Sergej Jaskiewicz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

The notice above is OpenCombine's, and it covers the work Combine is built from:
<https://github.com/OpenCombine/OpenCombine>, pinned at
1c6f02c7ed8140c0ba7a783aaddb6e0685a0037b. The `revenant@combine` package installs it
beside the sources and the libraries it builds from them, and it is the notice a
copy of this software must carry.

Combine is OpenCombine with a series of patches, the files in
`frameworks/Combine/patches/`, under the same MIT terms and with no other
claim over Sergej Jaskiewicz's work. The patches are ours, and they are:

- the core, the Dispatch scheduler and the Foundation integration made one
  module named `Combine`, with the declarations of the `OCombine` namespaces at
  Apple's level;
- the adaptations iOS 6 and earlier need: `DispatchTime` distances taken from
  the scheduler's own arithmetic, the run loop timer's tolerance read and set
  only behind `#available`, and `URLSession`'s data task publisher marked iOS 7;
- what OpenCombine does not have: `Publishers.Merge` through `Merge8` and
  `MergeMany`, `Publishers.CombineLatest` through `CombineLatest4`,
  `Publishers.CollectByTime` with `Publishers.TimeGroupingStrategy` and
  `collect(_:options:)`, the equality and hashing Apple's own interface declares
  in the open, and `Publishers.MapError`'s labelled initializer;
- the gyb helpers `MapKeyPath`'s template uses, defined in the template.

Copyright (c) 2026 kern0x1b
