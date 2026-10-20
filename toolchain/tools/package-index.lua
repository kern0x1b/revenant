import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

GROUPS = {
    ["build-tools"] = {"llvm", "llvm-clang-c", "swift", "swift-bootstrap", "swift-syntax", "ld64", "ldid", "gn", "libplist", "iphoneos-sdk"},
    runtimes = {"libcxx", "swift-runtime", "swift-embedded", "apple-compat", "revenant-coding"},
    frameworks = {"activitykit", "appintents", "appintents-macros", "createml", "musickit", "swift-data", "tipkit",
                  "widgetkit", "combine", "swiftui", "swiftui-uikit", "matter", "swift-crypto", "swift-system"},
    libraries = {"box2d", "ggml", "lz4", "lzfse", "micro-ecc", "monocypher", "opencv", "openssl", "picotls", "quicly",
                 "suitesparse-ordering", "xz", "zlib"},
    emulator = {"emulator", "emulator-guest", "firmware-tools", "swiftshader"},
    tweaks = {"apple-callkit-screen"}
}

local function declaration_findings(found, folder, name)
    local lua = path.join(folder, "xmake.lua")
    if not os.isfile(lua) then
        table.insert(found, string.format("%s has no xmake.lua, so the index serves no version of it", name))
        return
    end
    local declared = string.match(io.readfile(lua), 'package%("([^"]*)"%)')
    if not declared then
        table.insert(found, string.format("%s declares no package(...)", name))
    elseif declared ~= name then
        table.insert(found, string.format("%s declares package(%s), not %s", name, declared, name))
    end
end

function layout_findings(root, groups)
    groups = groups or GROUPS
    local found = {}
    local group_of = {}
    for group, names in pairs(groups) do
        for _, name in ipairs(names) do
            if group_of[name] then
                table.insert(found, string.format("the table puts %s under both %s and %s", name, group_of[name], group))
            end
            group_of[name] = group
        end
    end
    local filed = {}
    for _, folder in ipairs(os.dirs(path.join(root, "*"))) do
        local group = path.filename(folder)
        if not groups[group] then
            table.insert(found, string.format("%s is not a group; the groups are %s", group, table.concat(table.orderkeys(groups), ", ")))
        end
        for _, package in ipairs(os.dirs(path.join(folder, "*"))) do
            local name = path.filename(package)
            if filed[name] then
                local first, second = filed[name], group
                if second < first then
                    first, second = second, first
                end
                table.insert(found, string.format("%s is filed under both %s and %s", name, first, second))
            end
            filed[name] = filed[name] or group
            if not group_of[name] then
                table.insert(found, string.format("%s is in no group of the table", name))
            elseif group_of[name] ~= group then
                table.insert(found, string.format("%s is filed under %s, the table puts it under %s", name, group, group_of[name]))
            end
        end
    end
    for name, group in pairs(group_of) do
        if not filed[name] then
            table.insert(found, string.format("the table puts %s under %s, and there is no folder of it", name, group))
        end
    end
    byteorder.sort(found)
    return found
end

function index_findings(root, groups)
    local found = layout_findings(root, groups)
    for _, package in ipairs(os.dirs(path.join(root, "*", "*"))) do
        declaration_findings(found, package, path.filename(package))
    end
    byteorder.sort(found)
    return found
end
