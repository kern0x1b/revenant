function main(framework, classes, release, architectures, modules)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local source
    for _, architecture in ipairs(architectures:split(",")) do
        source = dyld.held_source(dyld.root() .. "/" .. release, architecture)
        if source then
            print(framework .. " on " .. release .. " (" .. architecture .. ", " ..
                  path.filename(source) .. "):")
            break
        end
    end
    if not source then
        print(release .. ": no cache held for " .. architectures)
        return
    end
    local cache = dyld.load(source)
    local libraries, control, owners = 0, false, {}
    for install, found in pairs(cache.libraries) do
        libraries = libraries + 1
        local exports = found.exports or {}
        if exports["_OBJC_CLASS_$_NSObject"] or exports["_objc_msgSend"] then
            control = true
        end
        for symbol in pairs(exports) do
            owners[symbol] = install
        end
    end
    print("  the cache holds " .. libraries .. " libraries; the control symbol is " ..
          tostring(control) .. " (a walk that cannot find NSObject would answer nothing)")
    local carried, missing, elsewhere = {}, {}, {}
    for line in io.lines(classes) do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" then
            local symbol = "_OBJC_CLASS_$_" .. name
            if owners[symbol] then
                table.insert(carried, name)
                if not elsewhere[name] then
                    elsewhere[name] = owners[symbol]
                end
            else
                table.insert(missing, name)
            end
        end
    end
    print(string.format("  the release carries %d of %d, and does not carry %d:",
                        #carried, #carried + #missing, #missing))
    for _, name in ipairs(missing) do
        local similar
        for symbol, install in pairs(owners) do
            if symbol:find(name, 1, true) or symbol:find(name:sub(3), 1, true) then
                similar = install
                break
            end
        end
        print(string.format("    %s%s", name, similar and ("  (something like it lives in " .. similar .. ")" or "")))
    end
end
