local surface = import("surface", {anonymous = true})
local hand = import("hand", {anonymous = true})
local order = import("order", {anonymous = true})

local HEADER_OK = "header-ok"
local GENERATED_REASON = "generated: every member is a stub"

local function sorted_unique(list)
    local seen, out = {}, {}
    for _, item in ipairs(list) do
        if not seen[item] then
            seen[item] = true
            table.insert(out, item)
        end
    end
    table.sort(out, order.less)
    return out
end

local function class_reasons(input, spec_apis, owned, hand_classes, candidates)
    local reasons = {}
    for _, cls in ipairs(candidates) do
        local why = {}
        if hand_classes[cls] then
            table.insert(why, "the package's own sources define the class")
        end
        local members = owned[cls] or {}
        if #members == 0 then
            table.insert(why, "no missing member rows in the surface")
        end
        for _, row in ipairs(members) do
            local canon = row.canon or surface.canonical_member(row.api, row.kind)
            if row.lang == "swift" then
                table.insert(why, "Swift-only member")
            elseif input.overridden[row.api] or input.overridden[canon] then
                table.insert(why, "override (hand code)")
            elseif not input.stub_keys[canon] then
                if not spec_apis[canon] then
                    table.insert(why, "member not in the header parse")
                else
                    table.insert(why, "no stub: " .. (input.skip_reasons[canon] or input.skip_reasons[row.api] or "not stubbed"))
                end
            end
        end
        reasons[cls] = why
    end
    return reasons
end

function decisions(input)
    local supers = input.supers
    local hand_classes = hand.class_names(input.tree)
    local owned = {}
    for _, row in ipairs(input.surface) do
        local status = input.led6[surface.key(row.kind, row.api)]
        if (row.kind == "method" or row.kind == "property") and status ~= HEADER_OK then
            local owner = string.match(row.api, "^[%-%+]%[([%w_]+)") or string.match(row.api, "^([%w_]+)%.")
            if owner then
                owned[owner] = owned[owner] or {}
                table.insert(owned[owner], row)
            end
        end
    end
    local spec_apis, candidate_set = {}, {}
    for _, r in ipairs(input.spec) do
        if r.kind == "method" or r.kind == "property" then
            spec_apis[surface.canonical_member(r.api, r.kind)] = true
            local status = input.led6[surface.key("class", r.cls)]
            if status ~= nil and status ~= HEADER_OK then
                candidate_set[r.cls] = true
            end
        end
    end
    local candidates = {}
    for cls in pairs(candidate_set) do
        table.insert(candidates, cls)
    end
    table.sort(candidates, order.less)
    local reasons = class_reasons(input, spec_apis, owned, hand_classes, candidates)
    local generated = {}
    for cls, why in pairs(reasons) do
        if #why == 0 then
            generated[cls] = true
        end
    end
    local changed = true
    while changed do
        changed = false
        for cls in pairs(generated) do
            local sup = supers[cls]
            if sup ~= nil and reasons[sup] ~= nil and not generated[sup] then
                generated[cls] = nil
                reasons[cls] = {"superclass " .. sup .. " is neither in the release nor generated"}
                changed = true
            end
        end
    end
    local out = {}
    for cls, why in pairs(reasons) do
        local reason = GENERATED_REASON
        if #why > 0 then
            reason = table.concat(sorted_unique(why), "; ")
        end
        out[cls] = {generated = generated[cls] == true, reason = reason}
    end
    return out
end
