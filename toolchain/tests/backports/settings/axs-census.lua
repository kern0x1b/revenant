function main(release, architecture, modules)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local source = dyld.held_source(dyld.root() .. "/" .. release, architecture)
    if not source then
        print(release .. ": no cache held for " .. architecture)
        return
    end
    local cache = dyld.load(source)

    local function isAccessibility(library)
        return library:find("Accessibility", 1, true) ~= nil
    end

    local ax_total, ax_axs, ax_other = 0, 0, {}
    local all_total, all_axs = 0, 0
    for library, found in pairs(cache.libraries) do
        for symbol in pairs(found.exports or {}) do
            if symbol:find("AX", 1, true) then
                all_total = all_total + 1
                if symbol:find("AXS", 1, true) then all_axs = all_axs + 1 end
                if isAccessibility(library) then
                    ax_total = ax_total + 1
                    if symbol:find("AXS", 1, true) then
                        ax_axs = ax_axs + 1
                    else
                        ax_other[symbol] = true
                    end
                end
            end
        end
    end

    print(string.format("release %s %s, %d libraries in the cache", release, architecture,
                        (function() local n = 0; for _ in pairs(cache.libraries) do n = n + 1 end; return n end)()))
    print("")
    print("the release's Accessibility libraries:")
    print(string.format("  AX-prefixed exports: %d", ax_total))
    print(string.format("  of which its own AXS/kAXS preference names: %d", ax_axs))
    print(string.format("  of which anything else: %d", (function()
        local n = 0; for _ in pairs(ax_other) do n = n + 1 end; return n
    end)()))
    print("")
    print("every library of the release, which is a different question:")
    print(string.format("  AX-prefixed exports: %d, of which AXS-named: %d", all_total, all_axs))

    local axs_in_surface = {}
    for library, found in pairs(cache.libraries) do
        if isAccessibility(library) then
            for symbol in pairs(found.exports or {}) do
                if symbol:find("AX", 1, true) then axs_in_surface[symbol] = true end
            end
        end
    end
    print("")
    print("CONTROL __AXSInvertColorsEnabled, a name that is in the surface: "
          .. (axs_in_surface["__AXSInvertColorsEnabled"] and "found" or "MISSING"))
    print("CONTROL __AXSCharonPlanted, a name that is not:                "
          .. (axs_in_surface["__AXSCharonPlanted"] and "FOUND, which cannot be" or "nil"))

    local subjects = {"Motion", "Blink", "Cursor", "Horizontal", "Vertical", "Border", "Slider", "Image",
                      "Hearing", "Pair"}
    print("")
    print("names in the Accessibility surface containing each word a preference about the five settings")
    print("would use, and each word a hearing-device answer would be justified or refuted by:")
    local matched = 0
    local seen = {}
    for _, word in ipairs(subjects) do
        local hits = {}
        for symbol in pairs(axs_in_surface) do
            if symbol:find(word, 1, true) then table.insert(hits, symbol) end
        end
        table.sort(hits)
        print(string.format("  %-11s %d", word, #hits))
        for _, symbol in ipairs(hits) do
            print("      " .. symbol)
            seen[symbol] = true
        end
        if word == "Pair" then
            print("      (two of the six are a class and its metaclass, not preferences: " ..
                  "_OBJC_CLASS_$_AXEventTapPair and _OBJC_METACLASS_$_AXEventTapPair)")
        end
        matched = matched + #hits
    end
    local distinct = 0
    for _ in pairs(seen) do distinct = distinct + 1 end
    print(string.format("  %-11s %d (sum) / %d distinct, across the %d words", "TOTAL", matched, distinct,
                        #subjects))
end
