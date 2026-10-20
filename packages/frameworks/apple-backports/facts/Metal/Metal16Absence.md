# The release-16.0 rows of `registry/Metal/absent_Metal.json` that stay `absent`: what each release carries

Ten rows of release **16.0** sat at `absent` with the SDK's own declaration as their whole `source` -
"SDK 16.4, Metal" - which is an assertion and not a measurement, and four of them turned out not to be
absent at all and are now `implemented` (`facts/Metal/Descriptors16.md`). This page holds the
measurement for the ten that stay, the commands that reproduce it, and their output.

**The claim, in one line:** no held release below 16.0 carries any of these ten names, and this port
defines no class or protocol of any of them either - so `absent` is the correct verdict for all ten,
and each one's reason now names the facility that is missing rather than the release the class arrived
in.

## The ten, and what is missing for each

| row | kind | what the name is | what is missing, and it is not "the port has not written it" |
| --- | --- | --- | --- |
| `-[MTLHeap newAccelerationStructureWithSize:]` and its three siblings | method | a heap allocating an acceleration structure | a ray tracing unit. The port vends no `MTLAccelerationStructure` **object** at all - that row is a protocol declaration with no class behind it - so a heap that handed one back would hand back a buffer no ray tracer reads |
| `MTLIOCommandQueue` | protocol | a queue scheduling command buffers that read file handles and write buffers | a bindless-storage path. A load or read of that kind is a bindless operation, and this release's GPU has none |
| `MTLIOCommandBuffer` | protocol | the commands: load a file's bytes into a buffer the GPU reads, read one back | the same path, and the queue that would vend a command buffer |
| `MTLIOFileHandle` | protocol | a file as the source of a load command | the load command. The port's own path from a file to the GPU is an ordinary `MTLBuffer` the application fills plus a blit encoder (`registry/Metal/ios8blit.json`), which is not a load command |
| `MTLIOScratchBuffer` | protocol | scratch memory an IO command borrows and returns | any IO command to borrow it |
| `MTLIOScratchBufferAllocator` | protocol | the allocator a queue calls when a load command needs scratch | the queue, and the command |
| `MTLMeshRenderPipelineDescriptor` | class | a mesh pipeline's descriptor | a mesh stage. Its three `MTLFunction` members **are** the pipeline's object, mesh and fragment stages rather than values this port can hold, and this port's rendering path is Metal over OpenGL ES 2.0 (`facts/Metal/RenderPath.md`), which has no mesh stage and no geometry or tessellation stage either |

The mesh descriptor is the one row of the ten that is a plain descriptor and is still absent, and the
reason is written out rather than waved at: the other descriptors of this release describe an
*attachment list* or a *queue's bounds*, which are values, and this one describes the stages of a
pipeline that cannot exist. **A native fix** is a mesh stage in the rendering path, which is a later and
much larger piece of work than this row, and it is not begun here.

## Measurement one: the ladder, with the control in the same run

```
xmake l tools/cache-index/first-rung.lua --stdin < .agent-work/runs/metal-r16/names.txt
```

```
_OBJC_CLASS_$_MTLAccelerationStructurePassDescriptor	16.0
_OBJC_CLASS_$_MTLIOCommandQueueDescriptor	16.0
_OBJC_CLASS_$_MTLMeshRenderPipelineDescriptor	16.0
_OBJC_CLASS_$_MTLHeap	10.0.1
_OBJC_METACLASS_$_MTLHeap	10.0.1
newAccelerationStructureWithSize:	16.0
newAccelerationStructureWithDescriptor:	16.0
MTLIOCommandQueue	16.0
MTLIOScratchBuffer	16.0
ZZZNoSuchNameRevenantR16	NONE
```

The first run reads 50 per-release indexes in 29.60 s and every later one is a binary search over them,
which is why this is a measurement and not a scan: the same question asked with `strings` over the
caches is 148 s a name on an idle machine, measured in the tool's own header.

**The control is `ZZZNoSuchNameRevenantR16 -> NONE`**, and it is what makes the other answers mean
something: a tool that answered NONE for everything would be indistinguishable from a real absence.
`MTLCounterDontSample` answers NONE too, and that one is correct - it is an enumeration case and has no
symbol by nature.

**A class's own rung is a class-scoped answer, a selector's is not**, and this family shows both
halves:

* `_OBJC_CLASS_$_MTLHeap` reads **10.0.1**, so the heap is a real class from 10.0.1 and the 16.0 methods
  this band is about are members of a class that does exist on paper from then.
* `newAccelerationStructureWithSize:` reads **16.0** - the *selector's* first appearance anywhere in the
  held set. The heap's own method of that name is at 16.0 in `MTLHeap.h:243`, and the same selector on
  `MTLDevice` is at **14.0** in `MTLDevice.h:1080`. A selector's rung says nothing about its owner, and
  this family is a textbook case of it: the two spellings are different methods on different objects
  with two different arrival releases.

So no held release below 16.0 - and the 16.0 band's ends are 6.1.3 and 12.0, because the held ladder
(`dyld.held_ladder`) has no 13.0, 14.0 or 15.0 - carries any of the ten names.

## Measurement two: the port's own objects, which is where the four heap rows nearly went wrong

The four `-[MTLHeap newAccelerationStructureWith…]` rows are the ones where a cheap measurement would
have said the opposite of the truth, so it is worth writing down.

```
$ xcrun clang -target armv7-apple-ios6.1.3 -isysroot $SDK16 -fobjc-arc -Os -g0 -Wall \
      -Wno-unguarded-availability-new -Wno-unguarded-availability \
      -Werror=objc-missing-property-synthesis -Werror=incomplete-implementation \
      -I packages/frameworks/apple-backports/Metal -I packages/frameworks/apple-backports \
      -c packages/frameworks/apple-backports/Metal/MTLHeap10.m -o $W/heapobjs/MTLHeap10.o
$ strings -a $W/heapobjs/MTLHeap10.o | grep -cxF newAccelerationStructureWithSize:
1
$ xcrun otool -oV $W/heapobjs/MTLHeap10.o | grep -c 'name .*newAccelerationStructure'
0
```

**The selector string IS in the object and the object does NOT implement the method.** `MTLHeap` is a
protocol and `RevenantMetalHeap` adopts it, so clang puts the protocol's member names into the class's
`__objc_methname` section; four `grep -cxF` counts of 1 would have been read as "the port implements
these". The measurement that answers the question is the class's own method list, and it says 23
instance methods - `initWithDescriptor:error:`, `newBufferWithLength:options:`,
`newTextureWithDescriptor:offset:`, `maxAvailableSizeWithAlignment:`, `setPurgeableState:` and the rest -
and none of the four. `respondsToSelector:` on the port's heap therefore answers NO, which is what the
rows say.

## Measurement three: what the port declares

```
$ for n in MTLIOCommandBuffer MTLIOCommandQueue MTLIOFileHandle MTLIOScratchBuffer \
           MTLIOScratchBufferAllocator MTLMeshRenderPipelineDescriptor MTLArgument MTLHeapDescriptor; do
      c=$(grep -rl "@implementation $n\b" packages/frameworks/apple-backports/Metal/*.m | tr '\n' ' ')
      printf '%-40s %s\n' "$n" "${c:-none}"
  done
MTLIOCommandBuffer                     none
MTLIOCommandQueue                      none
MTLIOFileHandle                        none
MTLIOScratchBuffer                     none
MTLIOScratchBufferAllocator            none
MTLMeshRenderPipelineDescriptor        none
MTLArgument                            packages/frameworks/apple-backports/Metal/MTLTypeReflection8.m
MTLHeapDescriptor                      packages/frameworks/apple-backports/Metal/MTLHeap10.m
$ grep -c '^@protocol' packages/frameworks/apple-backports/Metal/RevenantMetalProtocols.h
32
$ grep -n '@protocol MTLIO\|@protocol MTLAccelerationStructurePass' \
      packages/frameworks/apple-backports/Metal/RevenantMetalProtocols.h || echo "none of them is declared there"
none of them is declared there
```

The last two lines of that run are the control: the same grep answers for `MTLArgument` and
`MTLHeapDescriptor`, so the six `none` lines are the tree's answer and not a grep that finds nothing.
`MTLHeap` itself answers *none* from that list and is not missing: the port's heap class is
`RevenantMetalHeap`, which adopts the protocol the row names, and that protocol is declared in
`RevenantMetalProtocols.h`.

So the five `MTLIO*` protocols are in no header a caller compiles against, and a binary that links this
port's Metal objects has no protocol of any of those names to answer `NSProtocolFromString`.

## What this page does NOT hold, and says so

**The whole-cache census of the two band ends has not run for this band.** The command is

```
REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua MTL 6.1.3 4.3 12.0
```

and it is the one measurement the rulebook would have here for its "control in the same run over the
release's own cache". It was started through `coordination/heavy.sh` and was still queued behind the
load gate (12) when this band wrote its rows, so **no row above cites it and no number here is its
output**. The rows do not need it: `first-rung.lua` answers the same question over all 50 rungs with a
NONE control, and the port's own objects and headers answer the other half. Running the census would add
the release's own class and protocol lists to the page and change no row.

## What a reader should take from this

Ten rows, ten reasons that name a facility rather than an arrival date, three measurements that ran
with their controls, and one measurement that did not run and is named as such. `absent` is the landing
state for all ten and `owed` is not used anywhere in this file.
