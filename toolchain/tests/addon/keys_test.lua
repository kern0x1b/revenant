local PUBLISHED = {
    {name = "swift", version = "6.4.0", plat = "macosx", arch = "arm64", buildhash = "4648973d8a304053acec151f6de13019",
     key = "d349575648e4bc0a80fabc75900702b3"},
    {name = "swift-runtime", version = "6.4.0", plat = "iphoneos", arch = "armv7", buildhash = "cb0eb1a2bbf2414f9193e30704c50c8e",
     deps = {{"apple-compat", "cc7825357884477d903106eb4ee640b5"}, {"libcxx", "28e31299d6324b3bba3ea1d2837f6291"}},
     key = "2e6596b55e5ff9390e825f45dbf73d55"},
    {name = "libcxx", version = "23.1.1", plat = "iphoneos", arch = "armv7", buildhash = "f01b67fa07c14bd8ac68242228ff6996",
     deps = {{"apple-compat", "40f47fbaaf4841ef9a0fe85d29dcecb3"}},
     key = "68bc76bc1c21f989158b0184d29df790"},
    {name = "swift-runtime", version = "6.4.0", plat = "iphoneos", arch = "armv7", buildhash = "152604a9811040b28f7f92d5890c095c",
     deps = {{"apple-compat", "40f47fbaaf4841ef9a0fe85d29dcecb3"}, {"libcxx", "f01b67fa07c14bd8ac68242228ff6996"}},
     key = "9ce5c5286dcf51dedffbd9a0b497a836"},
    {name = "libcxx", version = "23.1.1", plat = "iphoneos", arch = "armv7", buildhash = "f01b67fa07c14bd8ac68242228ff6996",
     deps = {{"apple-compat", "d46eee4235b34e2e8ce1b5524c687019"}},
     key = "adac91a71ff1a173a122c6f990721c63"},
    {name = "swift-runtime", version = "6.4.0", plat = "iphoneos", arch = "armv7", buildhash = "e31234b2aea74924b9a7c75967c670c9",
     deps = {{"apple-compat", "d46eee4235b34e2e8ce1b5524c687019"}, {"libcxx", "f01b67fa07c14bd8ac68242228ff6996"}},
     key = "64ea5fea9aa742351453fec6ca6bd7af"},
}

local function package(row)
    local deps = {}
    for _, dep in ipairs(row.deps or {}) do
        table.insert(deps, {
            name = function () return dep[1] end,
            buildhash = function () return dep[2] end,
        })
    end
    return {
        name = function () return row.name end,
        version_str = function () return row.version end,
        plat = function () return row.plat end,
        arch = function () return row.arch end,
        buildhash = function () return row.buildhash end,
        librarydeps = function () return deps end,
    }
end

function failures(arguments)
    local found = {}
    local prebuilt = import("prebuilt", {rootdir = arguments.modules, anonymous = true})
    for _, row in ipairs(PUBLISHED) do
        local key = prebuilt.key(package(row))
        if key ~= row.key then
            table.insert(found, string.format("%s with build hash %s has the key %s, the release CI published is %s",
                                              row.name, row.buildhash, key, row.key))
        end
    end

    local tool = io.readfile(path.join(path.directory(path.directory(arguments.modules)), "tools", "keys.lua"))
    if tool:find("strhash128", 1, true) then
        table.insert(found, "tools/keys.lua hashes a key of its own; it must print the key prebuilt.key computes")
    end
    if not tool:find("prebuilt.key(", 1, true) then
        table.insert(found, "tools/keys.lua does not print prebuilt.key, the key the archive is released under")
    end
    return found
end
