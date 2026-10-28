# Metal v2: the GPU-driver reverse-engineering landscape

Status: research, 2026-10-28, for the coordinator. Background for the v2 question in
[Metal on iOS 6](metal-on-ios6.md), section 4.7 (a custom SGX driver). It is not a decision and not a build
commitment. Nothing was run on a device, in CI or in any worktree, and no leaked material was opened.

## Source key

`dossier` is [Metal on iOS 6](metal-on-ios6.md) in this folder. Evidence labels: **fetched** means the page was read
through the web-fetch tool, which returns a model-written summary. Quotes here come from that summary, so treat them
as pointers to check, not as verified text. **listing** is a directory listing read the same way. **snippet** is a
web-search excerpt only. **blocked** means a 403 or 404, so nothing was read.

| Tag | Source | Evidence |
| --- | --- | --- |
| [probe] | the on-device probe, as recorded in the dossier, sections 2.3, 5.2 and 7 | dossier |
| [asahi-1] | Alyssa Rosenzweig, "Dissecting the Apple M1 GPU, part I", https://alyssarosenzweig.ca/blog/asahi-gpu-part-1.html | fetched |
| [asahi-2] | the same series, part II, https://alyssarosenzweig.ca/blog/asahi-gpu-part-2.html (redirected from rosenzweig.io) | fetched |
| [asahi-3/4] | parts III and IV, https://rosenzweig.io/blog/asahi-gpu-part-3.html and -part-4.html, and "the end" post | snippet |
| [m1n1] | https://github.com/AsahiLinux/m1n1 | fetched |
| [m1n1-hv] | https://github.com/AsahiLinux/m1n1/tree/main/proxyclient/hv | listing |
| [mmiotrace] | https://www.kernel.org/doc/html/latest/trace/mmiotrace.html | fetched |
| [pantrace] | Phoronix, "Mesa 19.1 Panfrost Driver Gets Pantrace & Pandecode Support", https://www.phoronix.com/news/Panfrost-Pantrace-Pandecode | fetched |
| [panfrost-xdc] | Panfrost, XDC 2018 slides, via the Wayback Machine | snippet |
| [panfrost-docs] | https://docs.mesa3d.org/drivers/panfrost.html | fetched |
| [mali-t720] | Collabora, "Opening up Mali T720", https://www.collabora.com/news-and-blog/blog/2019/12/20/opening-up-mali-t720 | fetched |
| [lima] | https://docs.mesa3d.org/drivers/lima.html | fetched |
| [freedreno] | Mesa MR 22502 (cffrawdump), https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/22502, and the freedreno rnndb files | snippet |
| [envytools] | https://envytools.readthedocs.io/en/latest/ (index only) | fetched |
| [vita3k] | https://github.com/Vita3K/Vita3K (README) | fetched |
| [vita3k-2018] | Vita3K, summer 2018 progress report, https://vita3k.org/blog/2018-09-05-Summer-2018-Progress-Report | snippet |
| [vita3k-2021] | Vita3K, 3-year progress report, https://vita3k.org/2021/07/31/3-years-Progress-Report.html | snippet |
| [psvgxp] | https://github.com/motoharu-gosuto/psvgxp | fetched |
| [usse-gen] | VelocityRa usse-decoder-gen, listed at https://awesome.ecosyste.ms/projects/github.com%2Fvelocityra%2Fusse-decoder-gen | snippet |
| [sunxi] | https://linux-sunxi.org/SGX544MP/ReverseEngineering | blocked (403); snippet |
| [openpvrsgx] | openpvrsgx-devgroup list, 2021-11, https://lists.goldelico.com/pipermail/openpvrsgx-devgroup/2021-November/000475.html; LibrePlanet, https://libreplanet.org/wiki/Group:PowerVR_drivers | snippet |
| [pvrsgx-hwdoc] | https://github.com/embed-3d/PVRSGX_hwdoc, as named by the sunxi page | blocked (404) |
| [darling] | https://github.com/darlinghq/darling | fetched |
| [darling-loader] | https://docs.darlinghq.org/internals/basics/loader.html | fetched |
| [puredarwin] | SourceForge project page, https://sourceforge.net/p/puredarwin/, and OSNews coverage | snippet |
| [gnustep] | GNUstep GUI package listings (T2, FreshPorts) and https://mediawiki.gnustep.org/index.php/Gui | snippet |
| [ravynos] | https://github.com/ravynsoft/ravynos, the ravynOS FAQ and the v0.4.0pre3 release note | snippet |
| [sandcastle] | Tuxphones, Cult of Mac, TechSpot and androidworld coverage; https://www.corellium.com/blog/project-sandcastle (404); the Apple Wiki page (403) | snippet; blocked |
| [apple-imagination] | 2017 Apple and Imagination reporting (PCWorld); the 2020 licence deal (The Register, Electronic Design) | snippet |

## 1. Summary

- **iOS on non-Apple hardware barely exists.** iOS runs on Apple's SoCs under Apple's boot chain. No port of iOS to
  non-Apple hardware was found. The closest public work runs the other way: Android on an iPhone 7 [sandcastle].
  The adjacent space is reverse engineering of mobile GPU drivers, and that is rich.
- **The method transfers; the ISA does not.** Asahi's method (wrap the IOKit entry, dump the shared memory at
  submit, diff two submissions) is the most detailed public account of finding a GPU's command stream on a closed
  driver [asahi-1, asahi-2]. Nothing found ties AGX's instruction set to PowerVR (section 3.1).
- **The verdict stands.** The custom SGX543 driver is still multi-year and v2-or-never. Every public method above
  stops at the kernel boundary, or needs an oracle or a compiler we do not have (section 5).
- **The first falsifiable step is cheaper and better aimed than the dossier says.** The dossier aims it at IOKit
  payloads. The Asahi evidence says command data sits in shared memory that the payloads point to. A dump-and-diff
  test on the GL path answers the first question in one experiment, and it is gated by the owner's licence decision
  (section 4).

## 2. The layers, and where SGX543 stands

Every method here works on one layer. The layers are a way to see what a method can and cannot reach.

| Layer | What it is | Public method found | Status for SGX543 on iOS 6.1.3 |
| --- | --- | --- | --- |
| L1 boundary | the IOKit calls from the GL process to the kernel service | in-process wrapping of the IOKit entry [asahi-1, asahi-2, pantrace] | done: the probe hooked IOKit in-process and logged user-client types 0 to 2 and their selectors [probe, dossier 2.3] |
| L2 memory | the shared memory the process maps, where AGX keeps descriptors and command buffers [asahi-2] | dump all mapped shared memory after submit, then diff [asahi-1, asahi-2] | not done: the dossier records no memory dump |
| L3 structure | descriptors, command packets, handle tables | schema-first decoding (rnndb, pandecode) [freedreno, pantrace] | not started; needs L2 |
| L4 ISA | shader instruction encodings | field mapping against an oracle (psvgxp), reconstruction (Vita3K, sunxi) [psvgxp, vita3k, sunxi] | partly public for other SGX parts; SGX543 encodings unverified; no oracle on the device |
| L5 kernel and MMU | the kernel method table, firmware, GPU memory mapping | MMIO tracing needs a hypervisor or a kernel change (m1n1, mmiotrace) [m1n1, mmiotrace] | closed: `SGXDriver543` is not read, and compute type 3 is refused [probe] |
| L6 compiler and integration | the shader compiler and the driver around it | Lima and Panfrost: this is most of the later work [lima, mali-t720] | not started; the bulk of the cost |

## 3. Premise checks

### 3.1 "Apple's own GPUs are PowerVR lineage" is not supported

- In 2017, reporting said Apple would stop using Imagination's IP and move to its own in-house graphics architecture
  [apple-imagination].
- A 2020 licence deal gives Apple access to a wider range of Imagination IP. Imagination did not say which products it
  covers. The Register speculated that Apple's own GPUs may involve PowerVR patents; that is speculation [apple-imagination].
- No source read ties AGX's ISA to Rogue or SGX. The lineage argument should not carry weight in the v2 case. The method
  transfers at the level of boundary, memory and decoder, not at the ISA.

### 3.2 The brief's m1n1 framing is not what the Asahi GPU posts describe

- Asahi's GPU write-ups read in this session describe a wrapper inside the same process as a Metal app, injected with
  `DYLD_INSERT_LIBRARIES`, that wraps `IOConnectCallMethod` [asahi-1, asahi-2]. They do not describe m1n1 tracing.
- m1n1 is a bootloader and experimentation playground for Apple Silicon [m1n1]. Its `proxyclient/hv` directory holds
  per-device trace scripts, such as `trace_agx.py`, `trace_dart.py`, `trace_dcp.py`, `trace_nvme.py` and `trace_smc.py`
  [m1n1-hv]. Whether `trace_agx.py` is how the GPU was traced is not verified here.

### 3.3 "Command words travel in IOKit external-method payloads" (dossier 4.7)

- Asahi's evidence is that descriptors and command buffers live in shared memory, and that they point to each other,
  sometimes several layers deep. The handles in the IOKit calls were matched to the allocation returns [asahi-2].
- So the dossier's first test looks at the wrong place. The payloads carry handles and sizes. The words are in the
  memory they name. This is the analogy from AGX, and it is not evidence about SGX (section 8).

## 4. The cheapest falsifiable step, as the sources point to it (not run)

This is the method's first step, written for SGX543 and the GL path, which works on the device.

1. **Gate.** The owner decides whether the device trace and a memory dump are covered by the iOS licence
   (dossier 5.2, 6.3 items 37 and 38). The dump is the same kind of act as the trace. Nothing here runs before that.
2. **Find the memory calls.** The probe logged IOKit calls on types 0 to 2, but the dossier does not record which
   calls map memory into the process. Learn that first, from the existing trace.
3. **Dump at submit.** At each GL submission, dump every region the process has mapped as shared. Reuse the probe's
   in-process hook (`gltrace.c`, Substrate) so the dump sees what the GL app maps. Asahi did the same with `DYLD_INSERT_LIBRARIES`
   [asahi-1].
4. **Diff.** Take two draws that differ in one state, such as the clear colour. Dump both. Look for words that change
   only where the state changed, and for a table whose values match the handles the kernel returned [asahi-2].
5. **Read the result.**
   - No changing words beyond the expected buffers: the GL command stream is not in CPU-visible memory on this path.
     The custom route then stops at the kernel boundary, and that answer is cheap.
   - A stable structure that changes with the state: L3 begins, with a schema in the rnn style (section 6).

What this answers: whether a readable render command stream exists in memory the process can see. What it does not
answer: compute (type 3 is refused by the kernel, so GL data says nothing about it), the USSE encodings, the kernel
method table, or the compiler.

## 5. Re-assessment

**Does anything change the verdict that the custom driver is multi-year?** No. The reasons, in order of cost:

1. **Kernel and firmware are closed.** The GPU service is `SGXDriver543`, and compute type 3 is refused [probe].
   Asahi's method and Panfrost's tools work above the kernel [asahi-2, pantrace]. The tools that reach MMIO need a
   hypervisor or a kernel change: m1n1 needs an Apple boot chain under our control, and mmiotrace is x86-only and
   needs the kernel [m1n1, mmiotrace]. Neither exists for the 4S in any source read.
2. **The ISA is partly public and unverified for SGX543.** The public work is for SGX544, and for SGX543MP4+ in Vita
   hardware [sunxi, vita3k, psvgxp]. The encoder method (psvgxp) needs an oracle. On the Vita that oracle is Sony's
   closed assembler [psvgxp]. On the 4S it is not known.
3. **The compiler is most of the cost.** Lima's docs say the work is "largely decoupled from reverse engineering" now,
   and most of it is integration and the compiler [lima]. Collabora's T720 work went to a compiler change and tiler
   design [mali-t720]. For SGX the USSE shader compiler is a separate project (dossier 4.7 gate 5).
4. **The licence gate is open** (dossier 5.2). Nothing in this research changes it.

**Is there a cheaper first step?** Yes, and it is the one change in this note. The shared-memory dump test (section 4)
gives a yes or no on readable render command data, with the kernel and compiler untouched. It costs less than the
dossier's payload trace, and it aims at the right layer. It is still gated by the licence decision.

**Does it shorten the path to compute?** No. Type 3 is refused by the kernel. A capture of the GL path cannot pass that
refusal, and any compute route must go through a kernel method table that has not been read (dossier 4.5). Compute stays v2-or-never.

**A possible new oracle, untested.** If the GL driver's shader compile writes its USSE program into memory the process
maps, the device's own compiler becomes an oracle for the psvgxp method. No source says the program lives in process
memory. This is one more thing the L2 dump could show.

**What this does not change.** The v1 path (air2es, render only) is untouched. The fragment-GPGPU start in
dossier 4.1 needs no reverse engineering, and nothing here argues against it. Recommend that dossier 4.7's "cheapest
observable step" be rewritten around section 4, and that the coordinator decide that edit. This note does not edit the dossier.

## 6. Source table

Each row gives the project, what it is, its licence and class, the method or idea worth taking, and how it applies to
SGX543 on iOS 6.1.3. Classes: **(a)** usable within the licence's limits; **(b)** read for method only, never copied;
**(c)** forbidden, never opened.

| Project | What it is | Licence and class | Transferable method or idea | Applies to SGX543 on iOS 6.1.3 |
| --- | --- | --- | --- | --- |
| Asahi AGX, Rosenzweig "Dissecting the Apple M1 GPU" I to IV [asahi-1, asahi-2, asahi-3/4] | Reverse engineering of Apple's own GPU driver on macOS, from a wrapper in the same process as a Metal app | Blog posts (all rights reserved); facts and method cited. Asahi driver code not checked here. Class (b) | (1) Wrap the IOKit entry in-process; hook allocation, command-buffer creation and submission. (2) Dump all mapped shared memory after submit. (3) Diff dumps with one thing changed; find counters that step by a fixed offset. (4) Match a handle table to kernel returns | L1 exists: the probe hooks IOKit in-process. L2 is the gap: no memory dump is recorded. Analogy only; SGX is not evidenced |
| m1n1, AsahiLinux [m1n1, m1n1-hv] | Bootloader and hypervisor for Apple Silicon; per-device trace scripts in `proxyclient/hv` | GPLv2-or-later from 2.0.0; MIT through 1.9.9. Class (b), method only | Run the vendor OS as a guest and trace device MMIO per device-tree node | Not a first step. Needs a boot or hypervisor chain under our control on the 4S, which was not verified. MMIO is not the command stream |
| Linux mmiotrace [mmiotrace] | In-kernel MMIO logger. The mapping is marked not-present after `ioremap`; each access faults; the handler single-steps, decodes and logs width, value and PC | Kernel documentation: page states only kernel copyright. Code is GPL-2.0 (general knowledge, not checked here). Class (b) | Trap register accesses by page fault and log them with markers | Not usable as is: documented as x86 only. It is the one way to see MMIO without a hypervisor, and it would need a kernel change on the device. Untested and gated |
| Panfrost pantrace, pandecode, panwrap (Mesa 19.1, 2019) [pantrace, panfrost-xdc] | Split of capture and decode. Panwrap sits between the GLES driver and the kernel. Pandecode rebuilds mapped memory and job descriptors and disassembles shaders. Pantrace dumps the command stream whatever the kernel driver | Mesa core MIT (dossier table, not re-read here). Article facts cited. Class (a) facts, (b) code | The split: capture at the boundary and dump memory, then a decoder that turns the dump into jobs. Panfrost's Mali work began by tracing ARM's userspace 3D [panfrost-xdc, snippet] | The probe is the capture half. A pandecode-style decoder follows a yes from the diff test. It needs job layouts first; for SGX none exist. Panfrost's docs do not document these tools [panfrost-docs] |
| Lima, Mali-4xx Utgard [lima] | Community reverse-engineered Mesa driver, upstream in Mesa 19.1 and kernel 5.2. Ships mali-syscall-tracker, "a tool to dump the runtime of the closed source Mali driver" | Docs page states no licence for the tool. Driver is Mesa (MIT). Tool not read. Class (b) for the tool | The lesson: RE is front-loaded. The docs say the work is "largely decoupled from reverse engineering" now. Collabora's T720 port needed a compiler change and tiler work [mali-t720] | A readable command stream may be the easy part. The USSE compiler and integration are the bulk (dossier 4.7 gate 5) |
| freedreno, rnndb, envytools, cffdump and cffrawdump (Mesa) [freedreno, envytools] | Register and command-packet descriptions in rules-ng-ng XML (rnndb). Mesa's freedreno decoder reads them. cffrawdump builds a value database of unique registers, CP commands and shader instructions over many traces (Mesa MR 22502). envytools covers NVIDIA GPUs and ships envydis and envyas | rnndb: MIT-style header (dossier snippet). freedreno decode: Mesa MIT. envytools: no licence on the docs page, copyright 2013 only. Class (b) until the repo is read | Schema-first decoding: describe the words once, decode captures against them. Build a value database over many captures to classify words | A cheap place for facts from our captures. Our tools are Lua, so the schema would be a Lua table; the XML is an upstream format. Adreno and NVIDIA had kernel headers to check against. SGX's kernel side is closed, so no independent check exists |
| Vita3K, GPL-2.0 [vita3k, vita3k-2018, vita3k-2021] | PS Vita emulator. Recompiles Vita shaders (SGX543MP4+ class) to SPIR-V, then GLSL for a host GL backend. Its 2018 report says the team had to work out the instruction set itself | GPL-2.0 (README, fetched). Class (b): read for method, never copied | ISA reconstruction by decoding and checking against outputs | An ISA reference, not a driver. It never drives SGX hardware; it runs on host GPUs. SGX543MP4+ is the same family on paper; the match to the 4S is unverified |
| psvgxp and VelocityRa usse-decoder-gen [psvgxp, usse-gen] | psvgxp: an encoder generator for SGX543 USSE instruction groups. Fields are found by poking the Vita's `psp2shaderperf` with donor shaders, then brute-force tests. usse-decoder-gen: a generated C++ decoder for SGX543MP4+ | psvgxp: no licence stated, so rights are reserved. Class (b), method only. usse-decoder-gen: not checked. Class (b) until read | The field-mapping method: pick a group, vary the fields against an oracle, write the layout as data, generate an encoder, test it | Fits the USSE question. The oracle is the gap. On the Vita it is Sony's closed assembler. On the 4S the only candidate is the device's own GL compiler, whose output would have to be captured from memory. Untested |
| linux-sunxi SGX544MP reverse engineering [sunxi] | Wiki page on the SGX544MP. Snippet: a `pdump` tool produced `out2.prm`; USSE opcodes decoded; kernel-shim logging suggested | Page returned 403. CC-BY per dossier snippet; `sunxi:Copyrights` not read. Class (b) | Logging what the kernel shim is handed; `pdump`-style capture | SGX544, not SGX543. The shim is open there and closed on iOS. Only the decoding lessons apply |
| openpvrsgx and LibrePlanet PowerVR notes [openpvrsgx] | An open GPL kernel module over closed userspace, 2011 to 2021 | GPL (dossier). Class (b) | Lesson: watching traffic through the kernel driver alone does not reveal instruction details [LibrePlanet, snippet]. A 2021 reply says the project excludes RE [openpvrsgx, snippet] | Not applicable to iOS: our kernel service is closed, and openpvrsgx's kernel is open |
| PVRSGX_hwdoc, named by the sunxi page [pvrsgx-hwdoc] | Hardware documentation repository for PowerVR SGX | Unknown. The fetch returned 404 | None taken | **Do not open** until provenance and licence are established (section 7) |
| Darling [darling, darling-loader] | Runs macOS apps on Linux without a VM. `mldr` loads a Mach-O binary and hands control to Apple's open-source dyld. XNU, libSystem and Security come from Apple's open source; Foundation, AppKit, CoreAudio and CoreFoundation are reimplemented | GPL-3.0 (README, fetched). Class (b) | Keep Apple's open low layers and reimplement the high ones the app calls. An older Darling reimplemented dyld and was abandoned in 2017 [snippet] | Same shape as our backports, with no GPU path: Darling renders on host GL. Not applicable to SGX |
| PureDarwin [puredarwin] | A community Darwin: installer, documentation, add-ons. No GUI. A recent pivot toward a general-purpose OS (OSNews snippet, undated) | APSL and BSD per the SourceForge listing. APSL is outside our usable list: class (b). BSD parts (a) | How Apple's open Darwin is assembled | No graphics stack. Not applicable. Whether Apple's open source contains any SGX or AGX kext was not checked |
| GNUstep [gnustep] | AppKit (GUI) and Foundation reimplementation | GUI LGPL-2.0-or-later; tools GPL-3.0-or-later (packager listings). Base licence not confirmed. Class (b), behaviour only | Reimplement a framework's API over another backend | No SGX path. Read only for AppKit behaviour, if it is ever needed |
| ravynOS [ravynos] | FreeBSD with CMU Mach and Apple open-source code. Source compatibility first. A release note says trivial C and Objective-C programs compiled on macOS ran under its dyld; GUI apps did not run yet | BSD (SourceForge listing). Class (a) | The ABI lesson: binary compatibility needs near-exact ABI matching and breaks when Apple changes upstream (snippet) | Confirms the ABI lesson for our backports. Not a GPU project. helloSystem: not verified |
| Project Sandcastle, Corellium [sandcastle] | Android 10 on iPhone 7 (A10). Beta from March 2020. Not persistent; built on checkra1n and PongoOS. Custom drivers for display, touch, CPU, memory, storage and Wi-Fi worked; GPU, audio, cellular and camera were pending | News reports (snippets). The Apple Wiki returned 403 and Corellium's post 404. Class (a), facts cited | Bring-up order: display, input and storage first, GPU last. No public GPU reverse-engineering method was found | The most direct evidence that the GPU is the last and hardest driver to bring up, even for a funded team. Not a GPU method source. Apple sued Corellium in 2019 and dropped the case in 2021 (snippets); this is a licence caution only |
| Corellium GPU reverse engineering | None public found | n/a | n/a | Could not verify (section 8) |

## 7. Not applicable, and forbidden or gated

Not applicable, with the reason, so nobody chases these:

- **m1n1 hypervisor tracing, for the 4S.** It needs an Apple boot or hypervisor chain under our control. Nothing read
  shows that path on the 4S. Its trace scripts are per block on Apple Silicon, and none is for SGX.
- **mmiotrace.** x86 only, and it needs the kernel's `ioremap` path.
- **Vita3K as a driver.** It never drives SGX hardware. It is an ISA reference only.
- **openpvrsgx.** Its kernel is open and ours is not. Its own project excludes RE.
- **Darling, GNUstep, ravynOS, PureDarwin for GPU.** None has a path to an SGX. Their reimplementation pattern is already
  our backport architecture, and ravynOS adds the ABI lesson.
- **Corellium and Sandcastle for GPU.** The GPU was not working in the reports read, and no public GPU method was found.
- **Lifting AGX methods onto SGX.** The ISAs differ (section 3.1). Only the method transfers.

Forbidden and gated:

- **Leaked material (class c).** The leaked PowerVR SGX driver item and the leaked Cedarview DDK are named in the dossier
  (section 5.1). This research did not open either, and did not fetch the leak item.
- **PVRSGX_hwdoc.** Its provenance is unknown. Hardware documentation of unknown origin may be leaked material under the
  owner's rule. Do not open it until the owner or the coordinator has established where it came from.
- **Device trace and memory dump.** Gated by the iOS licence decision (dossier 5.2, 6.3 items 37 and 38). This note is not legal advice.
- **Licence rule conflict.** AGENTS.md says leaked source is read for behaviour; the owner's rule is that it is never
  opened. Dossier 5.1 flags this for the owner.

## 8. Could not verify

- **m1n1's hypervisor trap mechanism and trace contents.** The `proxyclient/hv` listing was read; the scripts and the
  Asahi wiki were not. The claim that m1n1 traces GPU command data is not supported by any Asahi GPU post read here.
- **linux-sunxi SGX544 page.** Blocked (403). Its method and opcode claims come from snippets only.
- **Henkaku SGX543 page.** Blocked by an anti-bot page. The Vita's SGX543 encodings are unread.
- **PVRSGX_hwdoc.** Fetch returned 404. Its contents and provenance are unknown.
- **Corellium's Sandcastle write-up and Apple Wiki page.** Blocked (404 and 403). The GPU status rests on news snippets, which date from March 2020.
- **Corellium's public GPU work.** None found.
- **Panfrost XDC 2018 slides.** Snippet only.
- **Lima's mali-syscall-tracker.** Its capture method and licence were not read.
- **envytools licence and the rnn format details.** Only the docs index was read.
- **psvgxp's licence.** None is stated on the page. Treated as rights reserved.
- **Vita3K's USSE decoder and its "partial" SGX543MP4+ status.** The README was read; the decoder was not. The partial status is from dossier 4.7.
- **Darling's ELF and Mach-O bridge.** The linked page was not read.
- **PureDarwin activity; GNUstep Base licence; ravynOS's conflicting listing on Darwin binaries; helloSystem.** Not settled.
- **Whether Apple's open Darwin source contains any SGX or AGX kext.** Not checked against `apple-oss-distributions`.
- **Whether AGX shares any ISA with PowerVR.** The 2020 deal's scope is unknown; the Register's link is speculation.
- **Whether SGX GL command streams are in CPU-visible shared memory.** No SGX evidence. The whole of section 4 depends on this.
- **Whether the iOS 6 kernel and the GL driver allow a same-process memory dump.** Untested.
- **Whether the memory dump is covered by the iOS licence.** Owner decision; not legal advice.
- **Asahi's clean-room argument.** Read from a search snippet that summarised Rosenzweig's text; not read in full.
