-- What the swift rule must do for a library of Swift, which no test here builds (a build needs the runtime), so the facts that
-- were found by building one are held in the rule's text: the archiver of xmake's Swift language has flags of its own, empty by
-- default; a program whose Swift is all in libraries needs the runtime its libraries import; and what calls Swift through the header
-- the compiler writes must be compiled after it.
function failures(opt)
    local found = {}
    local text = io.readfile(path.join(opt.modules, "..", "rules", "swift", "xmake.lua"))
    if not text:find('target:add("scarflags", "-cr"', 1, true) then
        table.insert(found, "a static library of Swift is archived by the Swift language's archiver, whose flags (scarflags) are empty: given the library's path and no -cr, ar reads the path as options")
    end
    local hook = text:match("before_link%(function %(target%)(.-)\n    end%)") or ""
    if not hook:find("target:orderdeps()", 1, true) or not hook:find("swift.objectfile", 1, true) then
        table.insert(found, "a program whose Swift is all in a library must name the runtime libraries that library imports, or they come after the frameworks on the link line and bind to the system's Foundation")
    end
    if not hook:find("if not runtime then", 1, true) or hook:find('requireconf("configs", "shared")) then\n            return', 1, true) then
        table.insert(found, "a program that carries the runtime links what it imports as one that shares it does: before_link must not return for a runtime that is not shared, or the package names every library for it and it carries the ones it never imports")
    end
    if not hook:find(":objectfiles()", 1, true) then
        table.insert(found, "before_link must read the imports of the objects added with add_files, which Swift compiled outside the build is")
    end
    if not text:find('target:set("policy", "build.fence", true)', 1, true) or not text:find("-emit-objc-header", 1, true) then
        table.insert(found, "a target that has the compiler write an Objective-C header must be built before what depends on it compiles, or the Objective-C finds no header")
    end
    -- A package that expands a macro of its own - SwiftData's @Model, for one - is a plugin the
    -- port's compiler has to be pointed at. The runtime's own plugins arrive through
    -- runtime_flags' `plugins`; a package's own must arrive the way its modules do, from the
    -- dependencies' environment, or a port can never use the macro it depends on.
    local loop = text:match("for _, dependency in ipairs%(target:orderpkgs%(%)%) do(.-)\n                end") or ""
    if not loop:find("CHARON_SWIFT_MODULES", 1, true) then
        table.insert(found, "a port compiles against every dependency's Swift modules, read from the dependencies' CHARON_SWIFT_MODULES")
    end
    if not loop:find("CHARON_SWIFT_PLUGINS", 1, true) then
        table.insert(found, "a port cannot expand a macro a dependency ships: the rule must read every dependency's CHARON_SWIFT_PLUGINS and pass each as a -plugin-path, the way it passes CHARON_SWIFT_MODULES as -I, or @Model and every other macro of ours is unreachable from a port")
    end
    if not text:find('{"-plugin-path", folder}', 1, true) then
        table.insert(found, "a collected plugin directory must reach the compiler as -plugin-path, which is what a #externalMacro's module: name is resolved against")
    end
    return found
end
