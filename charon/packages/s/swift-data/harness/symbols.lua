symbols = {}

symbols.pending = {
    "_$s20FoundationEssentials9PredicateV8evaluateySbxxQpKF",
    "_$s20FoundationEssentials9PredicateVMa",
    "_$s20FoundationEssentials9PredicateVMn",
    "_$s20FoundationEssentials4DateVMn",
    "_$s20FoundationEssentials4UUIDVACycfC",
    "_$s20FoundationEssentials4UUIDVMn",
    "_$s20FoundationEssentials4UUIDVSHAAWP",
    "_$s30FoundationInternationalization14SortDescriptorV7keyPaths010PartialKeyF0CyxGSgvg",
    "_$s30FoundationInternationalization14SortDescriptorVMa",
    "_$s30FoundationInternationalization14SortDescriptorVMn"
}

function symbols.module_of(name)
    local length, rest = name:match("^_%$[sS](%d+)(%a[%w_]*)")
    if not length then
        return nil
    end
    return rest:sub(1, tonumber(length))
end

function symbols.undefined_names(text)
    local names = {}
    for line in text:gmatch("[^\r\n]+") do
        local name = line:match("^%s*U%s+(%S+)") or line:match("^%s*(%S+)%s*$")
        if name then
            table.insert(names, name)
        end
    end
    return names
end

function symbols.classify(names)
    local counts, order = {}, {}
    for _, name in ipairs(names) do
        local owner
        if name:match("^_%$ss") then
            owner = "the runtime (libswiftCore)"
        elseif symbols.module_of(name) then
            owner = "module: " .. symbols.module_of(name)
        elseif name:match("^_OBJC_%a*CLASS_%$_") then
            owner = "a framework (objc class)"
        elseif name:match("^_swift_") then
            owner = "the runtime (libswiftCore)"
        else
            owner = "a framework (C symbol)"
        end
        if not counts[owner] then
            counts[owner] = 0
            table.insert(order, owner)
        end
        counts[owner] = counts[owner] + 1
    end
    table.sort(order, function (a, b)
        if counts[a] ~= counts[b] then
            return counts[a] > counts[b]
        end
        return a < b
    end)
    return counts, order
end

function symbols.check_pending(names)
    local present = {}
    for _, name in ipairs(names) do
        present[name] = true
    end
    local named = {}
    for _, name in ipairs(symbols.pending) do
        named[name] = true
    end

    local resolved, unlisted = {}, {}
    for _, name in ipairs(symbols.pending) do
        if not present[name] then
            table.insert(resolved, name)
        end
    end
    for _, name in ipairs(names) do
        local module = symbols.module_of(name)
        if module == "FoundationEssentials" or module == "FoundationInternationalization" then
            if not named[name] then
                table.insert(unlisted, name)
            end
        end
    end

    if #resolved == 0 and #unlisted == 0 then
        return true
    end
    local parts = {}
    if #resolved > 0 then
        table.insert(parts, table.concat(resolved, ", ") ..
            " is no longer undefined: charon@swift-foundation is installed, or the code stopped "
            .. "using it. Update PENDING in this file and the registry's reasons.")
    end
    if #unlisted > 0 then
        table.insert(parts, table.concat(unlisted, ", ") ..
            " is a swift-foundation symbol PENDING does not name: a new one is used and the list "
            .. "is incomplete.")
    end
    return false, table.concat(parts, "  ")
end

function symbols.main()
    local object = os.getenv("CHARON_SWIFTDATA_OBJECT")
    if not object or not os.isfile(object) then
        raise("symbols.lua needs CHARON_SWIFTDATA_OBJECT naming an object to read")
    end
    local undefined = os.iorunv("nm", {"-u", object})
    local names = symbols.undefined_names(undefined)
    local defined = os.iorunv("nm", {"-g", object}):gsub(" T | S | B ", " "):gsub("()", " ")
    print(string.format("SYMBOLS undefined=%d", #names))
    local counts, order = symbols.classify(names)
    for _, owner in ipairs(order) do
        print(string.format("UNDEFINED %5d  %s", counts[owner], owner))
    end
    local ok, why = symbols.check_pending(names)
    if ok then
        print("PENDING ok: all " .. #symbols.pending .. " swift-foundation symbols are undefined, and "
              .. "nothing else of theirs is")
    else
        print("PENDING FAILED: " .. why)
        os.exit(1)
    end
end

function symbols.control()
    local function run(name, names)
        local ok, why = symbols.check_pending(names)
        print(string.format("%-32s %s", name, ok and "PASS" or "RED"))
        if not ok then
            print("   " .. why)
        end
        return ok
    end

    local withOneResolved = {}
    for index, name in ipairs(symbols.pending) do
        if index ~= 1 then
            table.insert(withOneResolved, name)
        end
    end

    local withAnExtra = {}
    for _, name in ipairs(symbols.pending) do
        table.insert(withAnExtra, name)
    end
    table.insert(withAnExtra, "_$s20FoundationEssentials18WithCheckedContinuationV")

    local real = {}
    for _, name in ipairs(symbols.pending) do
        table.insert(real, name)
    end

    local objc = { "_OBJC_CLASS_$_NSPersistentContainer",
                   "_OBJC_METACLASS_$_NSManagedObject",
                   "_OBJC_IVAR_$__timestamp" }
    local counts, order = symbols.classify(objc)
    local classes = counts["a framework (objc class)"] or 0
    local others = 0
    for _, owner in ipairs(order) do
        if owner ~= "a framework (objc class)" then
            others = others + counts[owner]
        end
    end
    local c = (classes == 2 and others == 1)
    print(string.format("%-32s %s", "one CLASS, one METACLASS, one IVAR:",
                        c and "PASS" or "RED"))
    if not c then
        print(string.format("   %d landed in the class bucket and %d elsewhere, and it must be "
                            .. "2 and 1", classes, others))
    end

    local a = run("ten named, one resolved:", withOneResolved)
    local b = run("ten named, one unlisted:", withAnExtra)
    local control_green = run("the real list (control):", real)
    print(string.format("A is red=%s  B is red=%s  the control is green=%s  the objc buckets are "
                        .. "narrow=%s",
                        tostring(not a), tostring(not b), tostring(control_green),
                        tostring(c)))
    os.exit((not a and not b and control_green and c) and 0 or 1)
end

function main()
    local control, object = os.getenv("CHARON_SWIFTDATA_CONTROL"), os.getenv("CHARON_SWIFTDATA_OBJECT")
    if control then
        symbols.control()
    elseif object then
        symbols.main()
    else
        raise("symbols.lua does nothing without one of two: CHARON_SWIFTDATA_CONTROL=1 runs the " ..
              "control for check_pending, and CHARON_SWIFTDATA_OBJECT=<object or archive> reads " ..
              "an object's undefined symbols. Neither is set.")
    end
end
