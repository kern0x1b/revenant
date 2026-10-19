function main(classes, below, architectures, modules)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local source
    for _, architecture in ipairs(architectures:split(",")) do
        source = dyld.held_source(dyld.root() .. "/" .. below, architecture)
        if source then
            print("checking against " .. below .. " on " .. architecture .. " (" ..
                  path.filename(source) .. ")")
            break
        end
    end
    if not source then
        print(below .. ": no cache held for " .. architectures)
        return
    end
    local cache = dyld.load(source)
    local found = {}
    for line in io.lines(classes) do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" then
            for _, owner in ipairs({"Intents", "IntentsUI"}) do
                local install = "/System/Library/Frameworks/" .. owner .. ".framework/" .. owner
                if dyld.exported_by(cache, install, "_OBJC_CLASS_$_" .. name) then
                    table.insert(found, name)
                end
            end
        end
    end
    print(below .. " already exports " .. #found .. " of this group: " .. table.concat(found, " "))
end
