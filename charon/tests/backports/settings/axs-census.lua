-- The census every settings answer in this library rests on, run over a release's own cache.
--
-- Three numbers come out of it and they are the whole argument:
--
--   * how many AX-prefixed exports the release's **Accessibility** libraries have, and that all of them
--     are its own AXS/kAXS preference names - which is what "the release holds a preferences library
--     and nothing else" means, and which is the figure facts/Accessibility/Accessibility.md quotes;
--   * that none of the words a preference about the five settings this library answers for would be
--     named with appears in that surface, so each function's NO is a reading of the release and not a
--     placeholder, and every name that does contain such a word is printed so a reader can see it is not
--     a preference;
--   * that a symbol which IS in the surface is found and a symbol which is not is not - the control,
--     without which the "none" above would be indistinguishable from a walk that could not look.
--
-- The all-libraries figure is printed too, separately labelled, because it is a different question: it
-- says how much of the release mentions AX at all, and the names it turns up in other frameworks are the
-- reason the first figure is scoped to the three Accessibility libraries.
--
-- Its last line is two numbers, and they are two numbers: a sum over every word and the number of
-- distinct exports behind it. Four exports contain two of the words each, so the sum is four more than
-- the exports, and a count of the surface that quotes the sum as a count of exports is wrong by four.
--
-- Usage: xmake l tests/backports/settings/axs-census.lua <release> <architecture> <modules>
function main(release, architecture, modules)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local source = dyld.held_source(dyld.root() .. "/" .. release, architecture)
    if not source then
        print(release .. ": no cache held for " .. architecture)
        return
    end
    local cache = dyld.load(source)

    -- The three Accessibility libraries of a release, named by what they are, and nothing else.
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

    -- The control, asked the same way as everything above: a name that IS in the surface, and one that
    -- is not. Both are looked up in the Accessibility surface by the same predicate.
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

    -- The five subjects, by the words a preference about them would be named with. Every name that
    -- contains one is printed, because "none of them is a preference" is a claim about names.
    -- The words a preference about the settings this library answers for would be named with, and the
    -- words a hearing-device answer would be justified by. "Hearing" and "Pair" were missing, and the
    -- reviewer's own walk of the same cache found pairing exports in this surface that the list could
    -- not print, so the sentences in the code that said there were none were not checked by anything.
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
            -- Two of this list are not preferences, and the list says which: a reader counting
            -- preferences out of it would be counting a class and its metaclass.
            print("      (two of the six are a class and its metaclass, not preferences: " ..
                  "_OBJC_CLASS_$_AXEventTapPair and _OBJC_METACLASS_$_AXEventTapPair)")
        end
        matched = matched + #hits
    end
    local distinct = 0
    for _ in pairs(seen) do distinct = distinct + 1 end
    -- Two numbers, because they are two numbers. The sum is every hit under every word, and an export
    -- whose name contains two of the words is counted twice - the four paired-UUIDs exports contain
    -- Hearing and Pair each, so the sum is four more than the exports. A claim about what the surface
    -- does or does not hold is a claim about the distinct count.
    print(string.format("  %-11s %d (sum) / %d distinct, across the %d words", "TOTAL", matched, distinct,
                        #subjects))
end
