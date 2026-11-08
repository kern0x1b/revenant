function failures(opt)
    local interfaces = import("apple.swift_interface", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local interface = path.join(os.tmpdir(), "revenant-interface-blocks.swiftinterface")
    io.writefile(interface, table.concat({
        "import Foundation",
        "extension Foundation.NSNotification.Name {",
        "  @available(iOS, introduced: 4.0)",
        "  public static var First: Foundation.NSNotification.Name {",
        "    get {",
        "      Self(\"First\")",
        "    }",
        "  }",
        "}",
        "extension Foundation.NSObject {",
        "}",
        "extension Foundation.NSNotification.Name {",
        "  public static var Second: Foundation.NSNotification.Name {",
        "    Self(\"Second\")",
        "  }",
        "}",
    }, "\n") .. "\n")
    local blocks = interfaces.interface_blocks(interface, "extension Foundation.NSNotification.Name {")
    os.rm(interface)
    if #blocks ~= 2 then
        table.insert(found, string.format("an interface with two extensions of Foundation.NSNotification.Name must yield two blocks, not %d", #blocks))
        return found
    end
    if not blocks[1]:find("Self(\"First\")", 1, true) or blocks[1]:find("Second", 1, true) then
        table.insert(found, "the first block must be the first extension, whole and nothing more")
    end
    if not blocks[2]:startswith("extension Foundation.NSNotification.Name {") or not blocks[2]:endswith("\n}") then
        table.insert(found, "a block must run from its opening line to the closing brace at the start of a line")
    end
    return found
end
