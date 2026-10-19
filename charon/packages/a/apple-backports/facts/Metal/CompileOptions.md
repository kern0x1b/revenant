# MTLCompileOptions, iOS 8

Part of the Tier 2 Metal/MetalKit verdict (`coordination/corpus/2026-09-23`, corpus handoff
`2026-09-23-metal-63-and-remainder.md`): the earlier sweep marked the whole of Metal absent on the
reasoning that iOS 6.1.3 has no GPU driver. That reasoning does not reach a descriptor object,
which needs no driver to exist and hold the values it is given.

## The seam this plugs into, already honest

`MTLCompileOptions` exists purely as the parameter to
`-[id<MTLDevice> newLibraryWithSource:options:error:]`. This port's own `CharonMetalDevice.m`
already implements that method - it accepted an `MTLCompileOptions *` argument before this pass
touched anything - and already refuses honestly:

```
- (id<MTLLibrary>)newLibraryWithSource:(NSString *)source options:(MTLCompileOptions *)options error:(NSError **)error
{
    if (error)
        *error = CharonMetalError(3, @"Metal Shading Language source is not compiled on this system");
    return nil;
}
```

Carrying `MTLCompileOptions` as a real descriptor does not change that refusal or paper over it:
an application can now build a valid `MTLCompileOptions` instance (previously a LOAD-FAIL) and
hand it to a compiler that was already, correctly, declining to compile. The descriptor and the
compiler are different things, and only the compiler is walled - matching the coordinator's own
warning that a descriptor next to a missing compiler must not be presented as a solved seam.

## What the port does

`fastMathEnabled` defaults to `YES` as the header documents. `preprocessorMacros`, `languageVersion`
and the rest hold whatever is set and read back unchanged. Nothing in this port reads any of them,
since the one and only consumer refuses before it would ever inspect the descriptor's fields.
