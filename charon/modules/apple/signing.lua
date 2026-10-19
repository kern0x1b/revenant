local function plist_json(file)
    return import("core.base.json").decode(os.iorunv("plutil", {"-convert", "json", "-o", "-", file}))
end

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not same(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

function entitlement_problems(declared, signed)
    local problems = {}
    for _, key in ipairs(table.orderkeys(declared)) do
        if signed[key] == nil then
            table.insert(problems, key .. " is declared and the signature does not carry it")
        elseif not same(declared[key], signed[key]) then
            table.insert(problems, key .. " is declared differently from what the signature carries")
        end
    end
    return problems
end

function signed_entitlements(ldid, binary)
    local text = try { function () return os.iorunv(ldid, {"-e", binary}) end }
    if not text or text:trim() == "" then
        return {}
    end
    local file = os.tmpfile() .. ".plist"
    io.writefile(file, text)
    local found = plist_json(file)
    os.rm(file)
    return found
end

function sign(ldid, binary, opt)
    opt = opt or {}
    if not opt.entitlements then
        os.vrunv(ldid, {"-S", binary})
        return
    end
    if not os.isfile(opt.entitlements) then
        raise("%s is declared with entitlements %s, and there is no such file", binary, opt.entitlements)
    end
    os.vrunv(ldid, {"-S" .. opt.entitlements, binary})
    if opt.waived and opt.waived.entitlements then
        wprint("%s: entitlements not read back: %s", binary, opt.waived.entitlements)
        return
    end
    local problems = entitlement_problems(plist_json(opt.entitlements), signed_entitlements(ldid, binary))
    if #problems > 0 then
        raise("%s was signed without what %s declares: %s", binary, opt.entitlements, table.concat(problems, "; "))
    end
end
