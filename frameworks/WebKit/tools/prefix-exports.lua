local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/prefix-exports.lua HEADER SOURCE DESTINATION
  applies the Rev class prefix of HEADER (compat/stubs/ios6_class_prefix.h) to the exported-symbols list
  SOURCE and writes DESTINATION: the classes are renamed by a force-included header, which the list knows
  nothing about, so every _OBJC_CLASS_$_, _OBJC_METACLASS_$_ and _OBJC_IVAR_$_ name it gives is renamed
  too. The prefixed engine does this in every build.]]

function main(header, source, destination)
    if not header or not source or not destination then
        print(USAGE)
        return
    end
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local renamed = tree.modules("engine").prefix_exports(path.absolute(header), path.absolute(source), path.absolute(destination))
    print("%d symbols renamed", renamed)
end
