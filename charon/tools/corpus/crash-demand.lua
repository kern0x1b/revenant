import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})
local objc = import("objc_text", {rootdir = os.scriptdir(), anonymous = true})
local json_order = import("json_order", {rootdir = os.scriptdir(), anonymous = true})

local MINOS = {ish = {11, 0}, ppsspp = {11, 0}, pojav = {12, 2}, provenance = {16, 0},
               delta = {14, 0}, utm = {14, 0}, aidoku = {15, 0}, yattee = {14, 0},
               session = {15, 0}, telegram = {11, 0}}
local APPS = {"ish", "ppsspp", "pojav", "provenance", "delta", "utm", "aidoku", "yattee", "session", "telegram"}
local HW = {Metal = true, MetalKit = true, MetalPerformanceShaders = true, ARKit = true, CoreNFC = true, CoreHaptics = true}
local IMPL_PROTOCOLS = {UIContentContainer = true, UITraitEnvironment = true, UIFocusEnvironment = true}
local FRAMEWORKS_SESSION = {Photos = true, PhotosUI = true, AVFoundation = true, AVFAudio = true, AVKit = true,
                            CoreMedia = true, VideoToolbox = true, AudioToolbox = true, GameController = true,
                            Security = true, CoreTelephony = true, CoreGraphics = true, ImageIO = true,
                            CoreVideo = true, Accelerate = true, CoreImage = true, MobileCoreServices = true,
                            CoreServices = true, CoreText = true, QuartzCore = true, CoreMotion = true, MapKit = true,
                            OpenGLES = true}
local RANK = {implemented = 0, inert = 1, ignored = 2, owed = 3, absent = 4, undecided = 5}
local GAP = {"absent", "undecided", "ignored", "gap?"}
local GAPSET = {undecided = true, absent = true, ignored = true}
local CARRIED = {implemented = true, inert = true}
local CACHE_RUNGS = {{"7.0.1", {7, 1}}, {"10.3.4", {10, 3}}, {"12.0", {12, 0}}}

local function starts_with_any(text, prefixes)
    for _, prefix in ipairs(prefixes) do
        if text:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function head(status)
    return status:match("^[^(]*")
end

local function pyround(x)
    local f = math.floor(x)
    local diff = x - f
    if diff > 0.5 then
        return f + 1
    elseif diff < 0.5 then
        return f
    end
    return f % 2 == 0 and f or f + 1
end

local function ver(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local parts = {}
    for piece in (text .. "."):gmatch("([^.]*)%.") do
        table.insert(parts, tonumber(piece))
    end
    return parts
end

local function tuple_less(a, b)
    for index = 1, math.max(#a, #b) do
        if a[index] == nil then
            return b[index] ~= nil
        end
        if b[index] == nil then
            return false
        end
        if a[index] ~= b[index] then
            return a[index] < b[index]
        end
    end
    return false
end

local function min_by(items, key)
    local best, best_key = nil, nil
    for _, item in ipairs(items) do
        local k = key(item)
        if best == nil or tuple_less(k, best_key) then
            best, best_key = item, k
        end
    end
    return best
end

local function band(v)
    if v == nil then
        return "?"
    end
    local m = v[1]
    if m < 7 then return "<7" end
    if m == 7 then return "7" end
    if m <= 10 then return "8-10" end
    if m <= 12 then return "11-12" end
    if m <= 14 then return "13-14" end
    if m <= 16 then return "15-16" end
    return "17+"
end

local function bk_of(v)
    if v == nil then
        return nil
    end
    if v[1] <= 10 then return "7-10" end
    if v[1] <= 12 then return "11-12" end
    return "13+"
end

local function route(fw, band_)
    if fw == "CoreLocation" then return "CoreLocation" end
    if FRAMEWORKS_SESSION[fw] then return "frameworks" end
    local late = {["7"] = "7-10", ["8-10"] = "7-10/10", ["11-12"] = "11-12", ["13-14"] = "13-14",
                  ["15-16"] = "13-14+", ["17+"] = "later"}
    return late[band_] or "?"
end

local function version_text(v)
    return table.concat(v, ".")
end

local function desc(n)
    return string.format("%09d", 999999999 - n)
end

local function sorted_by(entries, key_of)
    local keyed = {}
    for index, entry in ipairs(entries) do
        keyed[key_of(entry) .. "\1" .. string.format("%07d", index)] = entry
    end
    local out = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        table.insert(out, keyed[key])
    end
    return out
end

local function set_list(set)
    local list = {}
    for item in pairs(set) do
        table.insert(list, item)
    end
    byteorder.sort(list)
    return list
end

local function count_of(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

local function tree_implementations(tree)
    local impls, order = {}, {}
    local files = {}
    for _, file in ipairs(os.files(path.join(tree, "**"))) do
        local ext = file:match("%.([^./]+)$")
        if ext == "m" or ext == "mm" or ext == "h" then
            table.insert(files, file)
        end
    end
    byteorder.sort(files)
    for _, file in ipairs(files) do
        local found = objc.implementations(io.readfile(file))
        for _, name in ipairs(byteorder.keys(found)) do
            if impls[name] == nil then
                impls[name] = {}
                table.insert(order, name)
            end
            for _, body in ipairs(found[name]) do
                table.insert(impls[name], body)
            end
        end
    end
    return impls, order
end

local function load_overrides(corpus)
    local overrides = {}
    local file = path.join(corpus, "decision-overrides.tsv")
    if os.isfile(file) then
        local first = true
        for line in io.lines(file) do
            if first then
                first = false
            else
                local q = {}
                for field in (line .. "\t"):gmatch("([^\t]*)\t") do
                    table.insert(q, field)
                end
                if #q >= 2 then
                    overrides[q[1]] = q[2]
                end
            end
        end
    end
    return overrides
end

local CARRIED_OVERRIDE_PHRASINGS = {"present-on-6", "implemented"}
local INERT_OVERRIDE_PHRASINGS = {"present-inert", "must-be-present-inert"}
local function normalize_override(raw)
    if starts_with_any(raw, GAP) or raw:sub(1, 5) == "inert" then
        return raw
    end
    if starts_with_any(raw, CARRIED_OVERRIDE_PHRASINGS) then
        return "implemented"
    end
    if starts_with_any(raw, INERT_OVERRIDE_PHRASINGS) then
        return "inert"
    end
    return "gap? implement -- " .. raw
end

local function protocol_member_finder(impls, order, imported)
    local function carrier_of(sel)
        for _, c in ipairs(order) do
            if imported[c] then
                local body = table.concat(impls[c], "\n")
                if sel:find(":", 1, true) then
                    local parts = {}
                    for p in sel:gmatch("[^:]+") do
                        table.insert(parts, p)
                    end
                    if #parts > 0 and objc.declares_selector(body, parts) then
                        return c
                    end
                else
                    local up = sel:sub(1, 1):upper() .. sel:sub(2)
                    if not objc.directive_names(body, "@dynamic", sel)
                            and (objc.declares(body, sel) or objc.declares_keyword(body, "set" .. up)) then
                        return c
                    end
                end
            end
        end
        return nil
    end
    return carrier_of
end

function main()
    local corpus = aggregate.corpus_dir()
    local sdk = aggregate.read_json(path.join(corpus, "sdk-introduced.json"))
    local universe = aggregate.selector_universe()
    local reg = aggregate.load_registry()
    local reg_kinds = aggregate.load_reg_kinds()
    local store = aggregate.load_store(false)

    local tree_candidates = {path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon", "packages", "a", "apple-backports")}
    if os.getenv("CHARON_TREE_DIR") then
        table.insert(tree_candidates, 1, os.getenv("CHARON_TREE_DIR"))
    end
    local tree = nil
    for _, candidate in ipairs(tree_candidates) do
        if tree == nil and os.isdir(candidate) then
            tree = candidate
        end
    end
    if tree == nil then
        raise("crash-demand.lua: no tree directory found (looked in %s). Set CHARON_TREE_DIR to the current "
            .. "worktree's packages/a/apple-backports -- without it protocol_member_in_tree() silently scans an empty "
            .. "blob and every protocol-owner row (e.g. GCDevice.vendorName) reports a false gap.",
            table.concat(tree_candidates, ", "))
    end
    local impls, impl_order = tree_implementations(tree)
    local imported_classes = {}
    for _, app in ipairs(APPS) do
        local d = store.apps[app]
        if d then
            for _, r in ipairs(d.demand) do
                if r.kind == "class" then
                    imported_classes[r.name] = true
                end
            end
        end
    end
    local carrier_of = protocol_member_finder(impls, impl_order, imported_classes)

    local reg_sel = {}
    for api, st in pairs(reg) do
        local sel = api:match("^[-+]%[[%w_]+ (.+)%]$")
        if sel and (RANK[st] or 9) < (reg_sel[sel] and RANK[reg_sel[sel]] or 9) then
            reg_sel[sel] = st
        end
    end

    local function class_version(owner)
        local e = sdk[owner]
        if e and e[2] then
            return ver(e[2])
        end
        return nil
    end
    local function kind_of(owner)
        local e = sdk[owner]
        return e and e[1] or "?"
    end

    local idx = {}
    local function add(sel, entry)
        idx[sel] = idx[sel] or {}
        table.insert(idx[sel], entry)
    end
    local sdk_text = io.readfile(path.join(corpus, "sdk-introduced.json"))
    for _, api in ipairs(json_order.top_level_keys(sdk_text)) do
        local e = sdk[api]
        local kind, v, fw = e[1], e[2], e[3]
        if kind == "method" then
            local _, owner, sel = api:match("^([-+])%[([%w_]+) (.+)%]$")
            if owner then
                add(sel, {intro = ver(v) or class_version(owner), api = api, owner = owner,
                          ownerkind = kind_of(owner), fw = fw, memberkind = "method"})
            end
        elseif kind == "property" then
            local dot = api:find(".", 1, true)
            if dot then
                local owner, name = api:sub(1, dot - 1), api:sub(dot + 1)
                local up = name:sub(1, 1):upper() .. name:sub(2)
                for _, sel in ipairs({name, "set" .. up .. ":", "is" .. up}) do
                    if not (sel == name and universe["is" .. up] and not universe[name]) then
                        add(sel, {intro = ver(v) or class_version(owner), api = api, owner = owner,
                                  ownerkind = kind_of(owner), fw = fw, memberkind = "property"})
                    end
                end
            end
        end
    end

    local overrides = load_overrides(corpus)
    local function status_one(c)
        local keys = {c.api}
        local owner_name = nil
        if c.memberkind == "property" then
            local dot = c.api:find(".", 1, true)
            local o, name = c.api:sub(1, dot - 1), c.api:sub(dot + 1)
            local up = name:sub(1, 1):upper() .. name:sub(2)
            keys = {c.api, "-[" .. o .. " " .. name .. "]", "-[" .. o .. " set" .. up .. ":]",
                    "-[" .. o .. " is" .. up .. "]", "+[" .. o .. " " .. name .. "]", "+[" .. o .. " set" .. up .. ":]"}
        end
        local st = nil
        for _, k in ipairs(keys) do
            if st == nil and reg[k] ~= nil then
                st = reg[k]
            end
        end
        if st == nil then
            local ost = reg[c.owner]
            if reg_kinds[c.owner] == "protocol" and (ost == "absent" or ost == "ignored") then
                ost = nil
            end
            if ost == "absent" or ost == "ignored" then
                st = ost
            elseif ost == "implemented" or ost == "inert" or ost == "owed" then
                st = ost .. "(class)"
            end
        end
        if st == nil and reg_kinds[c.owner] == "protocol" then
            local sel = nil
            if c.memberkind == "property" then
                sel = c.api:sub(c.api:find(".", 1, true) + 1)
            else
                sel = c.api:match("^[-+]%[[%w_]+ (.+)%]$")
            end
            local carrier = sel and carrier_of(sel)
            if carrier then
                st = "implemented(tree:" .. carrier .. ")"
            end
        end
        if st == nil and overrides[c.api] then
            st = normalize_override(overrides[c.api]) .. " (override)"
        end
        return st or "undecided"
    end

    local selcache = path.join(corpus, "selcache")
    local defcache = path.join(corpus, "defcache")
    local sends = {}
    for _, app in ipairs(APPS) do
        local mp = path.join(selcache, app .. ".json")
        local dp = path.join(defcache, app .. ".json")
        if os.isfile(mp) then
            local defined = {}
            if os.isfile(dp) then
                for _, s in ipairs(aggregate.read_json(dp)) do
                    defined[s] = true
                end
            end
            local set = {}
            for _, s in ipairs(aggregate.read_json(mp)) do
                if not universe[s] and not defined[s] then
                    set[s] = true
                end
            end
            sends[app] = set
        end
    end

    local class_holders = {}
    for app, d in pairs(store.apps) do
        for _, r in ipairs(d.demand) do
            if r.kind == "class" then
                class_holders[r.name] = class_holders[r.name] or {}
                class_holders[r.name][app] = true
            end
        end
    end

    local caches_candidates = {path.join(corpus, "caches")}
    if os.getenv("CHARON_CACHES_DIR") then
        table.insert(caches_candidates, 1, os.getenv("CHARON_CACHES_DIR"))
    end
    local caches_sel = nil
    for _, candidate in ipairs(caches_candidates) do
        if caches_sel == nil and os.isdir(path.join(candidate, "sel")) then
            caches_sel = path.join(candidate, "sel")
        end
    end
    if caches_sel == nil then
        raise("crash-demand.lua: no caches/sel/ directory found (looked in %s). This holds "
            .. "caches/sel/{7.0.1,10.3.4,12.0}.strings, ~870 MB, carried from the prior wave's scratchpad -- without it "
            .. "every selector missing from sdk-introduced.json is silently dropped instead of ranked. Set "
            .. "CHARON_CACHES_DIR to the directory that contains sel/, or restore coordination/corpus/caches/sel/.",
            table.concat(caches_candidates, ", "))
    end
    local caches_root = path.directory(caches_sel)

    local b60, ladder = aggregate.build_index(caches_root)
    local gap_class_syms = {}
    for _, rung in ipairs(ladder) do
        for sym in pairs(rung.attr) do
            gap_class_syms[sym] = true
        end
    end
    for sym in pairs(b60) do
        gap_class_syms[sym] = nil
    end

    local strs, rungs_read = {}, 0
    for _, rung in ipairs(CACHE_RUNGS) do
        local pth = path.join(caches_sel, rung[1] .. ".strings")
        if os.isfile(pth) then
            local set = {}
            for line in io.lines(pth) do
                set[line] = true
            end
            strs[rung[1]] = {up = rung[2], set = set}
            rungs_read = rungs_read + 1
        end
    end
    if rungs_read == 0 then
        raise("crash-demand.lua: %s exists but has none of 7.0.1/10.3.4/12.0.strings -- refusing to silently rank as "
            .. "if every unversioned selector were unmeasurable.", caches_sel)
    end
    local function upper_bound(sel)
        for _, rung in ipairs(CACHE_RUNGS) do
            local held = strs[rung[1]]
            if held and held.set[sel] then
                return held.up
            end
        end
        return nil
    end

    local sel_apps = {}
    for _, app in ipairs(APPS) do
        for s in pairs(sends[app] or {}) do
            if idx[s] then
                sel_apps[s] = sel_apps[s] or {}
                sel_apps[s][app] = true
            end
        end
    end

    local groups, group_order = {}, {}
    local dropped_no_version = {}
    local impl_only, old_sdk = 0, 0
    local unversioned = {}
    local HW_NAME = function (name)
        return name:find("MTL%u") ~= nil or name:find("CAMetal", 1, true) ~= nil
    end

    for _, s in ipairs(byteorder.keys(sel_apps)) do
        local apps = sel_apps[s]
        local known = {}
        for _, c in ipairs(idx[s]) do
            if c.intro then
                table.insert(known, c)
            end
        end
        local skip = false
        if #known == 0 then
            local ub = upper_bound(s)
            if ub == nil then
                table.insert(dropped_no_version, {sel = s, apps = set_list(apps)})
                skip = true
            else
                known = {}
                for _, c in ipairs(idx[s]) do
                    table.insert(known, {intro = ub, api = c.api, owner = c.owner, ownerkind = c.ownerkind,
                                         fw = c.fw, memberkind = c.memberkind})
                end
                unversioned[s] = true
            end
        end
        if not skip then
            local intro = min_by(known, function (c) return c.intro end).intro
            if intro[1] < 7 then
                old_sdk = old_sdk + 1
            else
                local first = min_by(known, function (c) return c.intro end)
                if HW[first.fw] or HW_NAME(first.api) then
                else
                    local sendable = {}
                    for _, c in ipairs(known) do
                        local protocol_callback = c.ownerkind == "protocol" and c.memberkind == "method"
                            and (c.owner:sub(-8) == "Delegate" or c.owner:sub(-10) == "DataSource" or IMPL_PROTOCOLS[c.owner])
                        if not protocol_callback then
                            table.insert(sendable, c)
                        end
                    end
                    if #sendable == 0 then
                        impl_only = impl_only + 1
                    else
                        local best = min_by(sendable, function (c) return c.intro end)
                        local key = best.api
                        local earliest, is_earliest = {}, {}
                        for _, c in ipairs(sendable) do
                            if not tuple_less(best.intro, c.intro) and not tuple_less(c.intro, best.intro) then
                                table.insert(earliest, c)
                                is_earliest[c] = true
                            end
                        end
                        local est = {}
                        for _, c in ipairs(earliest) do
                            table.insert(est, {c = c, st = status_one(c)})
                        end
                        local covered_e, gap_e = {}, {}
                        for _, e in ipairs(est) do
                            if GAPSET[head(e.st)] then
                                table.insert(gap_e, e)
                            else
                                table.insert(covered_e, e)
                            end
                        end
                        local pst = covered_e[1] and covered_e[1].st or gap_e[1].st
                        local notes = {}
                        if unversioned[s] then
                            table.insert(notes, "version unknown: introduced <= release whose strings contain it")
                        end
                        local later = {}
                        for _, c in ipairs(sendable) do
                            if not is_earliest[c] then
                                table.insert(later, {owner = c.owner, st = status_one(c)})
                            end
                        end
                        local gap_owner_set, carry_set = {}, {}
                        for _, e in ipairs(gap_e) do
                            gap_owner_set[e.c.owner .. ":" .. head(e.st)] = true
                        end
                        for _, o in ipairs(later) do
                            if GAPSET[head(o.st)] then
                                gap_owner_set[o.owner .. ":" .. head(o.st)] = true
                            end
                        end
                        for _, e in ipairs(covered_e) do
                            carry_set[e.c.owner] = true
                        end
                        for _, o in ipairs(later) do
                            if head(o.st) == "implemented" or head(o.st) == "inert" then
                                carry_set[o.owner] = true
                            end
                        end
                        local gap_owners = set_list(gap_owner_set)
                        local carry_owners = set_list(carry_set)
                        if #covered_e == 0 and #carry_owners == 0 and (reg_sel[s] == "implemented" or reg_sel[s] == "inert") then
                            table.insert(notes, "the registry has this selector " .. reg_sel[s] .. " on implementing classes, none on this declaring protocol/class")
                        end
                        if #covered_e == 0 and #carry_owners > 0 then
                            local shown = {}
                            for i = 1, math.min(3, #carry_owners) do
                                table.insert(shown, carry_owners[i])
                            end
                            table.insert(notes, "same selector is carried on " .. table.concat(shown, ",") .. ": check whether that covers this owner")
                        end
                        if groups[key] == nil then
                            groups[key] = {apps = {}, intro = intro, fw = best.fw, owners = #sendable, st = pst,
                                           ev = table.concat(notes, "; "),
                                           amb = (#covered_e > 0) and gap_owners or {},
                                           owner = best.owner, ownerkind = best.ownerkind}
                            table.insert(group_order, key)
                        end
                        for app in pairs(apps) do
                            groups[key].apps[app] = true
                        end
                    end
                end
            end
        end
    end

    local rows = {}
    for _, key in ipairs(group_order) do
        local g = groups[key]
        local crash, soft = {}, {}
        for app in pairs(g.apps) do
            if not tuple_less(MINOS[app], g.intro) then
                table.insert(crash, app)
            else
                table.insert(soft, app)
            end
        end
        byteorder.sort(crash)
        byteorder.sort(soft)
        local disp = key
        if g.owners > 1 then
            disp = key .. " (+" .. (g.owners - 1) .. " owners)"
        end
        local cls_note = ""
        local confirmed = {}
        if g.ownerkind == "class" and gap_class_syms["_OBJC_CLASS_$_" .. g.owner] then
            local holders = class_holders[g.owner] or {}
            for app in pairs(g.apps) do
                if holders[app] then
                    confirmed[app] = true
                end
            end
            if count_of(confirmed) == 0 and count_of(g.apps) > 0 then
                cls_note = "class-undecided: selector sent by " .. table.concat(set_list(g.apps), ",")
                    .. " but none hold " .. g.owner .. "'s class symbol -- likely a same-named selector on another class"
            end
        elseif g.ownerkind == "class" then
            confirmed = g.apps
            cls_note = "class-unverifiable: " .. g.owner .. "'s class symbol is not in the 7.0.1/10.3.4/12.0/18.0 cache ladder "
                .. "(baseline class predating iOS 6, or newer than our cache coverage) -- class_holders cannot have data "
                .. "for it by construction, name-based count kept"
        else
            confirmed = g.apps
            cls_note = "protocol-owner: not class-symbol-verifiable, name-based count only"
        end
        local cls_crash, cls_soft = {}, {}
        for app in pairs(confirmed) do
            if not tuple_less(MINOS[app], g.intro) then
                table.insert(cls_crash, app)
            else
                table.insert(cls_soft, app)
            end
        end
        byteorder.sort(cls_crash)
        byteorder.sort(cls_soft)
        table.insert(rows, {api = disp, kind = "selector", framework = g.fw, band = band(g.intro),
                            introduced = version_text(g.intro), apps = count_of(g.apps), crash = #crash, soft = #soft,
                            status = g.st, sev = #crash > 0 and "CRASH-ON-USE" or "soft", callers = crash,
                            ev = g.ev, amb = g.amb,
                            cls_apps = count_of(confirmed), cls_crash = #cls_crash, cls_soft = #cls_soft,
                            cls_callers = cls_crash, cls_note = cls_note})
    end

    local seen, seen_order = {}, {}
    for _, app in ipairs(APPS) do
        local d = store.apps[app]
        for _, r in ipairs(d and d.demand or {}) do
            local bare = r.name:gsub("^_+", "")
            if r.cat == "FRAMEWORK" and not aggregate.is_swift_mangled(r.name) and not HW[r.framework]
                    and not HW_NAME(bare) and bare:sub(1, 3) ~= "MTL" and bare:sub(1, 6) ~= "CAMetal" then
                local key = r.kind .. "\1" .. r.name .. "\1" .. r.framework .. "\1" .. tostring(r.band)
                if seen[key] == nil then
                    seen[key] = {kind = r.kind, name = r.name, framework = r.framework, band = r.band, apps = {}, strong = {}}
                    table.insert(seen_order, key)
                end
                seen[key].apps[app] = true
                if not r.weak then
                    seen[key].strong[app] = true
                end
            end
        end
    end
    for _, key in ipairs(seen_order) do
        local e = seen[key]
        local st = aggregate.carried_status(reg, e.kind, e.name, e.framework)
        if st ~= "n/a-A5" then
            if st == nil or st == "" or st == "gap?" then
                local bare = e.name:gsub("^_+", "")
                for _, k in ipairs({e.name, "_" .. e.name, bare, "_OBJC_CLASS_$_" .. e.name, "_OBJC_CLASS_$_" .. bare}) do
                    if overrides[k] then
                        st = normalize_override(overrides[k]) .. " (override)"
                        break
                    end
                end
            end
            local sd = sdk[e.name] or sdk[e.name:gsub("^_+", "")]
            local v = sd and sd[2] and ver(sd[2]) or nil
            local bb = e.band
            if v then
                bb = band(v)
            elseif e.band == "13+" then
                bb = "13-16"
            end
            local crash = set_list(e.strong)
            local soft_count = count_of(e.apps) - #crash
            table.insert(rows, {api = e.name, kind = e.kind, framework = e.framework, band = bb,
                                introduced = v and version_text(v) or "", apps = count_of(e.apps), crash = #crash,
                                soft = soft_count, status = st, sev = #crash > 0 and "LOAD-FAIL" or "soft",
                                callers = crash, ev = "", amb = {},
                                cls_apps = count_of(e.apps), cls_crash = #crash, cls_soft = soft_count,
                                cls_callers = crash, cls_note = ""})
        end
    end

    local classes6 = aggregate.class_universe()
    local function owner_of(api)
        api = api:gsub(" %(%+%d+ owners%)$", "")
        local owner = api:match("^[-+]%[([%w_]+) ")
        if owner then
            return owner
        end
        local dot = api:find(".", 1, true)
        if dot and not starts_with_any(api, {"-", "+", "_"}) then
            return api:sub(1, dot - 1)
        end
        return nil
    end
    local function is_member(api)
        if starts_with_any(api, {"-", "+"}) then
            return true
        end
        return api:find(".", 1, true) ~= nil and api:sub(1, 1) ~= "_"
    end
    local function api_band(api)
        local e = sdk[api]
        if e and e[2] then
            return bk_of(ver(e[2]))
        end
        return nil
    end
    local function exists(o)
        return classes6[o] or CARRIED[reg[o]]
    end
    local sib = {}
    local decided = {}
    for _, api in ipairs(byteorder.keys(reg)) do
        local st = reg[api]
        local o = owner_of(api)
        if o and is_member(api) and (CARRIED[st] or st == "absent") and kind_of(o) ~= "protocol" then
            local bk = api_band(api)
            if bk == "7-10" or bk == "11-12" then
                local key = o .. "\1" .. bk
                sib[key] = sib[key] or {}
                table.insert(sib[key], CARRIED[st] == true)
                table.insert(decided, {o = o, bk = bk, is_c = CARRIED[st] == true})
            end
        end
    end
    local hit = {}
    for _, d in ipairs(decided) do
        local tag, pred
        if not exists(d.o) then
            tag, pred = "class-undecided", false
        else
            local list = sib[d.o .. "\1" .. d.bk]
            local others = {}
            local removed = false
            for _, value in ipairs(list) do
                if not removed and value == d.is_c then
                    removed = true
                else
                    table.insert(others, value)
                end
            end
            if #others >= 2 then
                local carried_n = 0
                for _, value in ipairs(others) do
                    if value then carried_n = carried_n + 1 end
                end
                pred = carried_n * 2 >= #others
                tag = pred and "likely-carry" or "likely-absent"
            end
        end
        if tag then
            hit[tag] = hit[tag] or {0, 0}
            hit[tag][2] = hit[tag][2] + 1
            if pred == d.is_c then
                hit[tag][1] = hit[tag][1] + 1
            end
        end
    end
    local precision = {}
    local hit_summary = {}
    for tag, pair in pairs(hit) do
        precision[tag] = {pair[1] / pair[2], pair[2]}
        table.insert(hit_summary, string.format("%s: %d%% of %d", tag, pyround(100 * pair[1] / pair[2]), pair[2]))
    end
    byteorder.sort(hit_summary)
    for _, r in ipairs(rows) do
        r.hint = ""
        if r.kind == "selector" and starts_with_any(r.status, {"undecided"}) then
            local o = owner_of(r.api)
            local bk = bk_of(ver(r.introduced))
            local tag
            local carried_list = o and sib[o .. "\1" .. (bk or "")] or {}
            if bk == "13+" then
                tag = "band-13+ unstarted"
            elseif o and kind_of(o) == "protocol" then
                tag = "protocol-owner"
            elseif not (o and exists(o)) then
                tag = "class-undecided"
            elseif #carried_list < 2 then
                tag = "no-signal"
            else
                local carried_n = 0
                for _, value in ipairs(carried_list) do
                    if value then carried_n = carried_n + 1 end
                end
                tag = carried_n * 2 >= #carried_list and "likely-carry" or "likely-absent"
            end
            local pr = precision[tag]
            r.hint = tag .. (pr and string.format(" (%d%% of %d)", pyround(100 * pr[1]), pr[2]) or "")
        elseif starts_with_any(r.status, {"gap?", "undecided"}) then
            r.hint = "symbol: needs a decision"
        end
    end
    print("hint hit rates (leave-one-out, decided members, bands 7-12): " .. table.concat(hit_summary, ", "))

    local gaps = {}
    for _, r in ipairs(rows) do
        if starts_with_any(r.status, GAP) and r.crash > 0 then
            table.insert(gaps, r)
        end
    end
    gaps = sorted_by(gaps, function (r)
        return desc(r.cls_crash) .. "\1" .. desc(r.crash) .. "\1" .. desc(r.apps) .. "\1"
            .. (r.sev == "LOAD-FAIL" and "0" or "1") .. "\1" .. r.band .. "\1" .. r.api
    end)
    local out = path.join(corpus, "crash-demand-top.tsv")
    local file = assert(io.open(out, "w"))
    file:write("rank\tseverity\tapi\tkind\tframework\tband\troute\tintroduced\tapps\tcrash_apps\tsoft_apps\t"
        .. "class_confirmed_apps\tclass_confirmed_crash_apps\tclass_confirmed_soft_apps\t"
        .. "registry\thint\tcrash_callers\tclass_confirmed_callers\tclass_note\tevidence\n")
    for i, r in ipairs(gaps) do
        file:write(string.format("%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n",
            i, r.sev, r.api, r.kind, r.framework, r.band, route(r.framework, r.band), r.introduced,
            r.apps, r.crash, r.soft, r.cls_apps, r.cls_crash, r.cls_soft, r.status, r.hint,
            table.concat(r.callers, ","), table.concat(r.cls_callers, ","), r.cls_note, r.ev))
    end
    file:close()

    local amb = {}
    for _, r in ipairs(rows) do
        if #r.amb > 0 and r.crash > 0 then
            table.insert(amb, r)
        end
    end
    amb = sorted_by(amb, function (r) return desc(r.crash) .. "\1" .. r.api end)
    file = assert(io.open(path.join(corpus, "crash-demand-ambiguous-owners.tsv"), "w"))
    file:write("unguarded_callers\tapps\tframework\tintroduced\tprimary_row(status covered)\tprimary_status\t"
        .. "other_owners_not_covered\tcallers\n")
    for _, r in ipairs(amb) do
        file:write(string.format("%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", r.crash, r.apps, r.framework, r.introduced, r.api,
            r.status, table.concat(r.amb, "; "), table.concat(r.callers, ",")))
    end
    file:close()

    dropped_no_version = sorted_by(dropped_no_version, function (d) return desc(#d.apps) .. "\1" .. d.sel end)
    file = assert(io.open(path.join(corpus, "crash-demand-dropped.tsv"), "w"))
    file:write("selector\tapps\tcallers\treason\n")
    for _, d in ipairs(dropped_no_version) do
        file:write(string.format("%s\t%d\t%s\tno version in sdk-introduced.json and not found in any of 7.0.1/10.3.4/12.0.strings -- genuinely unmeasurable, not silently skipped\n",
            d.sel, #d.apps, table.concat(d.apps, ",")))
    end
    file:close()

    local diverge, unconfirmed, unverifiable = 0, 0, 0
    for _, r in ipairs(gaps) do
        if r.cls_crash ~= r.crash then diverge = diverge + 1 end
        if starts_with_any(r.cls_note, {"class-undecided"}) then unconfirmed = unconfirmed + 1 end
        if starts_with_any(r.cls_note, {"class-unverifiable"}) then unverifiable = unverifiable + 1 end
    end
    print(string.format("ambiguous-owner rows (primary owner covered, another owner not): %d", #amb))
    print(string.format("crash-level gap rows: %d  (callback-only selectors set apart: %d; sdk<7 dropped: %d)",
        #gaps, impl_only, old_sdk))
    print(string.format("dropped, no version and no upper bound (counted, not silent -- see crash-demand-dropped.tsv): %d",
        #dropped_no_version))
    print(string.format("class-symbol vs name-based count diverge: %d rows  (class-symbol-unconfirmed, likely name collision: %d; "
        .. "class-unverifiable, pre-iOS-6 owner, name-based count kept: %d)", diverge, unconfirmed, unverifiable))
    print("-> " .. out)
    print("\nTOP 45 overall (ranked by class-symbol-confirmed crash exposure):")
    for i = 1, math.min(45, #gaps) do
        local r = gaps[i]
        local flag = r.cls_crash == r.crash and "" or string.format("  (name-based said %d)", r.crash)
        print(string.format("%2d %-12s %d/%-2d %-5s %-16s %-11s %s%s", i, r.sev, r.cls_crash, r.cls_apps, r.band,
            r.framework, r.status, r.api, flag))
    end
    return gaps
end
