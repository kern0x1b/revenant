# Carry a framework and order the Backports in an application

Two things an application that links a prebuilt engine and the Backports package needs: the framework the engine package installs has to be in the bundle where the import check can see it, and the Backports libraries have to come before the Swift runtime in the link line.

## Carry a framework from a package

`app.frameworks` names packages. A package that installs a `.framework` under `bundle/Frameworks/` has it placed in the bundle's `Frameworks` folder as `Name.framework/Name`, next to the plain libraries of the package. The framework keeps its install name, which has to be `@executable_path/Frameworks/Name.framework/Name`, so an application that links it by that name loads it from its own bundle.

```lua
target("Host")
    add_rules("@addon/revenant/app")
    add_packages("webkit-engine-prefixed")
    set_values("app.frameworks", "libcxx", "webkit-engine-prefixed")
```

The import check reads the placed framework as an image of the application. Without it the check refuses the application with `loads @executable_path/Frameworks/Name.framework/Name, which neither the device nor this build provides`, because a framework copied through `app.resources` is not an image the application declares. A package that installs neither a library nor a framework under `bundle/Frameworks/` is refused when the application is built.

## Order the Backports before the Swift runtime

An application that takes the `backports` package has the package's libraries ordered before every other library of its link line. The `app` rule does this with `linkorders`. libswiftFoundation, libswiftUIKit and the other runtime libraries re-export the system frameworks, and the linker binds an import to the first library of the command line that exports it. With the runtime first, a symbol that both the system framework and a Backports library export, such as `_CFRunLoopTimerSetTolerance` and `_kCTFontManagerRegisteredFontsChangedNotification`, binds to the framework, where the iOS 6 release leaves it NULL.

Nothing is declared in the application: the order follows from `add_packages("backports")`. The import check reports `link libXBackports.dylib before X` when an image is still bound the other way; an image that is not linked from source is rebound with [revenant.rebind](rebind.md).
