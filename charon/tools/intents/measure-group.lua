-- Which of a group's classes a release *below* the group's own already exports.
--
-- The band check refuses an object that defines both a class the band's release has and one it
-- does not (modules/apple/backports.lua's band(): "an object carries API that arrived in one
-- release, so split it"). The 6.1.3 gate links the deployment band alone and cannot see that;
-- the package build stages every band and does. This walks the release below the group's own and
-- names the classes of the group it exports, which are exactly the ones that have to be objects of
-- their own.
--
-- Usage: xmake lua <this> <classes> <release-below> <architectures> <modules>
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
