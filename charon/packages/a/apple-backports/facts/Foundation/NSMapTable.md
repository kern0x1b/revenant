# NSMapTable's iOS 6.0 factories

iOS 6.0 adds `+strongToStrongObjectsMapTable`, `+weakToStrongObjectsMapTable`, `+strongToWeakObjectsMapTable` and
`+weakToWeakObjectsMapTable`. NSMapTable itself is in every armv7 cache from 3.0, so an image that sends them links on
4.3 and fails at the call with an unrecognized selector: the imports check does not see it. The package carries all four
for releases before 6.0 in `Foundation/NSMapTable+Objects6.m`.

## What the releases hold

The class methods of NSMapTable in the armv7 caches of 4.3, 5.0, 5.1.1, 6.0 and 7.0 (`objc.inventory`): 4.3 to 5.1.1
have `+mapTableWithKeyOptions:valueOptions:`, `+mapTableWithStrongToStrongObjects`, `+mapTableWithWeakToStrongObjects`
and the rest of the old names, and none of the four 6.0 factories; 6.0 and 7.0 have all four (the selector strings of
the caches: `strongToWeakObjectsMapTable` and `weakToWeakObjectsMapTable` twice each in the 6.0 and 6.1 caches, in none
of 4.3, 5.0 and 5.1.1).

Measured under `xmake emulate` on iPhone2,1 4.3 (8F190) and 5.1.1 (9B206), a probe run under manual reference counting:

- 4.3 has no weak references in its runtime (`objc_storeWeak` absent); 5.1.1 has them.
- On both, a table made with `NSPointerFunctionsZeroingWeakMemory` keys, and the one `+mapTableWithWeakToStrongObjects`
  makes, keeps a released key's entry: after the key is deallocated `-count` still says 1, and enumerating the keys
  hands out the dead key (4.3: one key enumerated, then the next enumeration crashes with SIGSEGV; 5.1.1: SIGSEGV on the
  first). Neither is a weak table in 6.0's sense.
- `NSPointerFunctionsWeakMemory` (5) is refused on 4.3 and 5.1.1 by `-[NSMapTable initWithKeyOptions:valueOptions:capacity:]`
  with `NSInternalInconsistencyException`, "Requested configuration not supported", and
  `+[NSPointerFunctions pointerFunctionsWithOptions:]` answers nil for it. For zeroing weak memory (1 << 0) it answers
  functions with weak barriers, no acquire or relinquish and the object personality's hash and equality: what 6.0's
  `+weakToStrongObjectsMapTable` answers for its keys (6.0 under the same probe).
- `[[NSMapTable subclass alloc] init]` is an `NSConcreteMapTable` on 4.3, 5.1.1 and 6.0 alike.
- A key's associated objects are released with it on 4.3 and 5.1.1 for every class tried: NSObject, NSString made
  with a format, NSMutableString, NSNumber, NSArray, NSMutableDictionary, NSDate, NSData, NSURL and NSSet — the
  bridged CoreFoundation classes (`NSCFString`, `__NSCFDictionary`, `__NSCFSet`, `NSCFNumber`) among them.
- On 6.0 the release's strong and weak tables ignore `-setObject:nil forKey:` (the value stays) and
  `-setObject:forKey:nil`, answer nil for `-objectForKey:nil`, and describe themselves as
  `NSMapTable {\n[slot] key -> value\n}\n`.

So before 6.0 no NSMapTable of the release can hold keys or values that are let go and forgotten once nothing else
holds them.

## What the package does

- `+strongToStrongObjectsMapTable` is `+mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
  valueOptions:NSPointerFunctionsStrongMemory`: the release's own table, keys retained and not copied, values retained,
  as 6.0's.
- `+weakToStrongObjectsMapTable`, `+strongToWeakObjectsMapTable` and `+weakToWeakObjectsMapTable` are
  `CharonWeakMapTable`, an NSMapTable subclass made with the sides that are weak. Each entry holds a strong side
  strongly and a weak side unretained; a weak side's object holds a small watch as an associated object, and the watch,
  released with the object, marks that side of the entry gone and queues the entry on its table. Not a `__weak`
  reference: on 4.3 that is the SDK's arclite (`packages/i/iphoneos-sdk/arclite/weak.m`), which learns of a death
  through NSObject's `-release` and so aborts for an object that keeps its own retain count - measured, the first
  NSMutableString key ended the port's run on 4.3 with "cannot form weak reference to instance ... of class
  NSCFString". Entries are found by the key's `-hash` and `-isEqual:`, as the object personality finds them. A table
  drops the entries that were queued, with what they held, before it is next read or changed - work in the entries that
  went, not in every entry each time; a removed entry lets go of what it held at once.
- The watches an object carries are as many as the entries of live tables it is in, a side each. Every path that takes
  an entry out of its table (`-removeObjectForKey:`, `-removeAllObjects`, the table's own dealloc, an entry dropped for a
  side that went) takes the watches of both sides off the objects that live on, by setting the association to nil, and
  a value replaced does the same for the old value: an object that is put in a table and taken out a thousand times
  carries none afterwards, and a table discarded while its keys live leaves none on them (held by
  `tests/backports/host/maptable6`, which counts the port's own watch objects made and gone).
- NSMapTable's `+alloc` and `+allocWithZone:` hand out `NSConcreteMapTable` whichever class they are sent to, and its
  `-init` and `-copy` are abstract and raise `NSMapTableAbstractImplementationError` (measured on the host's
  Foundation; 4.3's NSMapTable lists the same methods). So the subclass makes its instances with `class_createInstance`
  and implements every public method itself: `-objectForKey:`, `-setObject:forKey:`, `-removeObjectForKey:`,
  `-removeAllObjects`, `-count`, `-keyEnumerator`, `-objectEnumerator`, `-dictionaryRepresentation`,
  `-keyPointerFunctions`, `-valuePointerFunctions`, fast enumeration, `-copy`, `-copyWithZone:`,
  `-mutableCopyWithZone:`, `-allKeys`, `-allValues` and `-description` (whose index is the entry's place in the
  enumeration: the table has no slots). `-keyPointerFunctions` and `-valuePointerFunctions` are the release's own for
  zeroing weak memory on a weak side and for strong memory on the other.
- The table archives as 6.0's weak tables do: class NSMapTable, then unkeyed the key options and the value options (5
  for a weak side, 0 for a strong one), each key and value, and nil (6.0's own archive under the same probe, for all
  three; 4.3's zeroing and strong tables write the same shape with their options). 6.0 decodes the port's archive as
  its own weak table. **Not carried: decoding such an archive before 6.0** - the release decodes "NSMapTable" as its
  own `NSConcreteMapTable`, and 4.3's and 5.1.1's refuse key options 5 there with "Requested configuration not
  supported" (measured). That, and `+mapTableWithKeyOptions:` with `NSPointerFunctionsWeakMemory` itself, which
  JavaScriptCore and CallKit in this package also use, need the release's NSMapTable to take weak memory before 6.0: a
  change of its own, not in this one.
- After a key or a value goes the release's table still counts its entry, and keeps what the entry holds, until the
  table next grows (the host, and 6.0 under `xmake emulate`: a count of 4 for 3 live entries, back in step when the
  fourth is added at 7; the held side of the entry still alive after the count is asked); the port forgets the entry
  before it answers, and lets go of what it held. Both are held by `tests/backports/host/maptable6`, which fails if
  the divergence stops. What the release's enumerations and lookups answer is the same as the port's (a dead side is not
  handed out on 6.0).
- **Reading a key or a value that is being freed on another thread.** An object's watch is released in `object_dispose`,
  after the object's `-dealloc` has run, so between the object's last release taking its retain count to zero and that
  release of its associations the table's pointer is to an object that is being freed, and a thread that retains it there
  takes hold of an object that is freed under it. Closed as far as the releases allow:
  - **5.0 and later: closed.** A weak side is also held by a `__weak` reference, and every read of a side goes through it;
    the runtime's own `objc_storeWeak` clears it at the start of deallocation, so no read retains an object that is
    going. `__weak` to `NSMutableString`, `NSString` made with a format, `NSNumber`, `NSDate`, `NSArray` and `NSObject` was
    tried under `xmake emulate` on iPhone2,1 5.0 (9A334), 5.1.1 (9B206) and 6.0: each is set and is nil after the object
    is released (4.3: `NSObject` is set and released, `NSMutableString` aborts, below). The path is chosen by looking for
    `objc_loadWeakRetained` in libobjc alone (`dlopen` of it with `RTLD_NOLOAD`, `dlsym` on that handle), not in every image:
    arclite, linked into a process, exports a function of that name of its own, and it is the one that aborts for
    `NSCFString`. The suite reads the path from an entry and holds it to the release's Foundation version: the `__weak`
    reference on 5.0, 5.1.1 and 6.0, the watch alone on 4.3 (libobjc's answer on 4.3 is none: `probes/weak.m` prints, on 4.3, `libobjc handle: non-NULL` and `dlsym objc_loadWeakRetained: NULL` (`objc_storeWeak` and `objc_loadWeak` NULL as well), so the `dlopen` worked and the symbol is absent; on 5.0, 5.1.1 and 6.0 the handle is non-NULL and all three are found). The owner thread enumerating a table's keys (reading each
    key's `-hash`) and taking `-copy` while other threads dropped the keys and values, `NSMutableString` keys and values and
    then `NSNumber` ones, 200000 rounds each: clean for the three tables on 5.0, 5.1.1 and 6.0, the release's own tables on
    6.0 as well. On the host an enumeration probe of the same shape (100000 rounds, `NSObject` keys) against the port before
    this change (an entry read through its unretained pointer) ended in SIGSEGV in each of 3 runs, at the first table. `control.sh` runs the same suite against a copy of the
    port whose lookup answers "none": it fails on 5.1.1 and on 6.0 in two runs, the path check first and then a crash in the
    enumeration (SIGSEGV in one run, SIGABRT in the other), so the test tells the two paths apart.
  - **A class that refuses a weak reference** (`-allowsWeakReference` answering NO) as a weak side: 6.0's own three factories
    abort (`cannot form weak reference to instance of class ...`, SIGILL) for each of the four weak sides (the key of
    `weakToStrong`, the value of `strongToWeak`, both sides of `weakToWeak`), and the port does the same on 5.0, 5.1.1 and
    6.0; the same class as either side of `strongToStrong` is held and found, so it is the weak side that refuses. Nothing
    is dropped silently at those releases, and the outcome is 6.0's. The port on 4.3, which forms no weak reference, holds
    the entry and finds it: it does not abort where 6.0 does. `emulate.sh` compares the outcome of each case with 6.0's on 5.0 and later, and on 4.3 holds it to `held, count 1, lookup found`.
  - **4.3: not closed, only narrowed.** The runtime has no `objc_storeWeak`, and arclite's abort for the objects that keep
    their own retain count (`cannot form weak reference to instance of class NSCFString: it manages its own retain count`,
    measured on 4.3 with an `NSMutableString`), so a watch is all there is and it runs after the object's `-dealloc`
    (`-release` cannot be watched for objects with their own retain count). What is closed there is everything but a read
    of another entry's side: an entry is found by its hash first, so a call on the table reads a key only for the key it was
    asked for or one whose hash equals it; taking a watch off an object that is going is done with the lock held, which the
    object's own watch needs to finish its `-dealloc`, so that object is whole for as long as the lock is; the owner thread
    adding entries, asking `-count` and `-objectForKey:` of a live key, while other threads dropped the keys and values, 200000
    rounds a table, clean for all three tables on 4.3 and 5.1.1 under `xmake emulate`. What is left is
    **the calls that read every entry's key** (the enumerators, `-dictionaryRepresentation`, `-copy`) and **a key equal to
    a key that is going**: `-objectForKey:` and `-setObject:forKey:` with a key whose hash is that of a key another thread is
    dropping read the dying key in `-isEqual:` once the hashes match, and for value-like keys (strings, numbers) an equal
    key is the ordinary case, not a collision. The same enumeration as above on 4.3 ends in SIGSEGV within 1.1 guest seconds (`probes.sh`, run again: 0.1 guest seconds, the
    same `pc`; 5.1.1 clean in the same run).
    It is a property of learning of a death through an association, so nothing native closes it on 4.3, and it is in
    `coordination/crutches.md`. Keep the last release of a weak key or of a weak value from happening on another thread while
    the table is enumerated or copied, or while it is asked for, or given, a key equal to one that may be going. A table is
    not thread-safe otherwise, as NSMapTable is not.
- `charon_watch` answers the watch's address, not the watch. Measured on 4.3, 5.1.1 and 6.0 under `xmake emulate`: with
  the watch returned as an object, every watch taken off its object stayed alive (the count of live watches only grew,
  1000 after 1000 set-and-remove of one key) while the same source on the host freed it at once. The reading: ARC's
  claim of an object returned to a caller that only stores its address is an iOS 8 runtime function, so below it the
  returned object stays in the autorelease pool until the pool drains. Only the count and the moment of the free
  were affected, not the answers of the table.

## How it is held

`tests/backports/host/maptable6` drives the port and the host's own factories through the same scenarios side by side, for
each of the three weak factories: live keys, an equal key keeping the first, a key not retained and its entry going with
it, values retained, removal, mutation during enumeration, copy, nil keys and values, string and number keys going with
their entries, a value going with its entry or replaced, the pointer functions, nested enumeration, and the archive; the
divergences named above; the watches left on an object that lives on; and the work a table of a thousand keys takes,
counted in reads of an entry's key (a scan of every entry on every call reads it n times n); and, for each of the three, the owner thread adding
entries, asking `-count` and a live key's value while blocks on a concurrent queue drop the keys and values (20000 rounds; `MAPTABLE6_ROUNDS` sets the
device build's), and, where the release has weak references, the same with the enumerators and `-copy` for `NSMutableString` and
`NSNumber` keys and values, on the port and on the release's own tables.
Negative controls, run once: a table that scans every entry on every read fails the work check (500540 reads for 1000
keys against a limit of 20000), one that does not take its watches off fails the watch checks, and one whose watch marks nothing when its object
goes ends in SIGSEGV on the dead object (a watch that only leaves the object's pointer alone is not caught: the entry is
queued and dropped before any read, which is the point of the queue).

`sh tests/backports/host/maptable6/emulate.sh` (in a heavy slot: `coordination/heavy.sh sh ...`) builds the same test as a
device binary through the `daemon` rule against the addon v0.8.10 in the shared store and runs it under `xmake emulate` on
iPhone2,1, on 6.0 against the release's own factories and on 4.3, 5.0 and 5.1.1, which have none, alone; it then compares the
port's answers to the 14 scenarios of each factory (42 answers) on 4.3, 5.0 and 5.1.1 with the release's on 6.0. Measured (200000 rounds): 137
checks, 0 failures on 6.0; 75 on 5.0 and on 5.1.1; 66 on 4.3, where the enumeration and `-copy` phase is skipped and says so in the log (6.0 has more than 5.0 and 5.1.1
because it also runs the release's own factories through every check); the 42
answers of 4.3, 5.0 and 5.1.1 identical to 6.0's; the refusal cases of the weak side (above) on each, compared with 6.0's for
5.0 and later. 140 checks on the host.
