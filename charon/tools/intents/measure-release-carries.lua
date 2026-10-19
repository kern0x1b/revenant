-- What a release the port targets already carries of a framework's class list.
--
-- A framework that arrived before the port's deployment is not a backport at all: the release has
-- the classes and the release's own binaries answer for them, so a band drops the package's
-- objects and re-exports the release's symbols. The first measurement of such a framework is
-- therefore not "what does the SDK declare" but "which of those names is already there".
--
-- **The search is over every library in the cache, not over one install path.** An earlier version
-- of this file built the path as /System/Library/Frameworks/<name>.framework/<name> and asked
-- whether that one library exported a symbol - and answered "not carried" for every symbol of a
-- framework that is not a framework at all, which is how it "measured" that iOS 6.1.3 has no
-- AppleArchive. It does not have one, but that was luck, not the measurement: the lookup had no
-- way of finding it anywhere. A C library lives at /usr/lib/lib<name>.dylib, a private one under
-- PrivateFrameworks, and a symbol may be re-exported by anything.
--
-- So the walk visits every library, counts the ones it saw, and prints a control: a symbol it must
-- find, so "found nothing" is a measurement rather than a broken probe.
--
-- Usage: xmake lua <this> <framework> <classes> <release> <architectures> <modules>
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
        -- A bare name may be a C symbol or a renamed one; say where anything similar lives.
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
