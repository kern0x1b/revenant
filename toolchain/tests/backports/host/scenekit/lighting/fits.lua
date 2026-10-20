local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "common"), anonymous = true})

local function say(...)
    local parts = {}
    for i, value in ipairs({...}) do
        parts[i] = value
    end
    print(table.concat(parts, " "))
end

local function lin_byte(b)
    local c = b / 255.0
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function enc_byte(l)
    l = math.max(0.0, math.min(1.0, l))
    local c
    if l <= 0.0031308 then
        c = l * 12.92
    else
        c = 1.055 * l ^ (1 / 2.4) - 0.055
    end
    return pyish.pyround(c * 255)
end

local function lin_unit(c)
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function enc_unit(l)
    l = math.min(math.max(l, 0), 1)
    if l <= 0.0031308 then
        return l * 12.92
    end
    return 1.055 * l ^ (1 / 2.4) - 0.055
end

local function norm(v)
    local n = math.sqrt(0 + v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
    return {v[1] / n, v[2] / n, v[3] / n}
end

local function dot(a, b)
    return 0 + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function D_ggx(nh, a2)
    local d = nh * nh * (a2 - 1) + 1
    return a2 / (math.pi * d * d)
end

local function G_schlick(nl, nv, k)
    return (nl / (nl * (1 - k) + k)) * (nv / (nv * (1 - k) + k))
end

local function G_smith_corr(nl, nv, a2)
    local lv = nl * math.sqrt(nv * nv * (1 - a2) + a2)
    local ll = nv * math.sqrt(nl * nl * (1 - a2) + a2)
    return 0.5 / (lv + ll) * (4 * nl * nv)
end

local function rotx(v, t)
    return {v[1], v[2] * math.cos(t) - v[3] * math.sin(t), v[2] * math.sin(t) + v[3] * math.cos(t)}
end

local function lines_starting(file, prefix)
    local out = {}
    for line in pyish.lines_of(file) do
        if line:sub(1, #prefix) == prefix then
            table.insert(out, line)
        end
    end
    return out
end

local function dict_repr(keys, values)
    local parts = {}
    for i, key in ipairs(keys) do
        table.insert(parts, "'" .. key .. "': " .. values[i])
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function tuple_repr(values)
    local parts = {}
    for i, value in ipairs(values) do
        if type(value) == "boolean" then
            parts[i] = value and "True" or "False"
        elseif type(value) == "string" then
            parts[i] = "'" .. value .. "'"
        elseif math.type(value) == "integer" then
            parts[i] = tostring(value)
        else
            parts[i] = pyish.float_repr(value)
        end
    end
    return "(" .. table.concat(parts, ", ") .. ")"
end

local function spec(dir)
    local groups = {}
    for _, line in ipairs(lines_starting(path.join(dir, "dense.txt"), "spec ")) do
        local r = pyish.split(line)
        local model = r[2]:gsub("SCNLightingModel", "")
        local sh = pyish.float(r[3]:sub(6))
        local a = pyish.float(r[4]:sub(3))
        local v = pyish.float(r[5])
        local found = nil
        for _, group in ipairs(groups) do
            if group.model == model and group.sh == sh then
                found = group
            end
        end
        if not found then
            found = {model = model, sh = sh, pts = {}}
            table.insert(groups, found)
        end
        table.insert(found.pts, {a, v})
    end
    table.sort(groups, function(x, y)
        if x.model ~= y.model then
            return x.model < y.model
        end
        return x.sh < y.sh
    end)
    local S = lin_byte(0.5 * 255)
    for _, group in ipairs(groups) do
        local model, sh, pts = group.model, group.sh, group.pts
        local best = nil
        for x = 1, 1999 do
            local k = x * 0.5
            for nl = 0, 1 do
                local err, n = 0, 0
                for _, point in ipairs(pts) do
                    local a, v = point[1], point[2]
                    if not (v >= 254 or v <= 1) then
                        local base = model == "Blinn" and math.cos(a / 2) or math.cos(a)
                        local pred = S * base ^ k * (nl == 1 and math.cos(a) or 1)
                        err = err + (lin_byte(v) - pred) ^ 2
                        n = n + 1
                    end
                end
                if n > 0 and (best == nil or err < best[1]) then
                    best = {err, k, nl, n}
                end
            end
        end
        if best then
            say(model, "shininess", pyish.float_repr(sh), "-> exponent", pyish.float_repr(best[2]),
                best[3] == 1 and "NdotL" or "", "rms", pyish.float_repr((best[1] / best[4]) ^ 0.5), "n", tostring(best[4]))
        end
    end
    print("--- free scale")
    for _, group in ipairs(groups) do
        local model, sh, pts = group.model, group.sh, group.pts
        local best = nil
        for x = 1, 799 do
            local k = x * 0.5
            for nl = 0, 1 do
                local num, den = 0, 0
                local use = {}
                for _, point in ipairs(pts) do
                    if 1 < point[2] and point[2] < 254 then
                        table.insert(use, point)
                    end
                end
                for _, point in ipairs(use) do
                    local a, v = point[1], point[2]
                    local base = model == "Blinn" and math.cos(a / 2) or math.cos(a)
                    local f = S * base ^ k * (nl == 1 and math.cos(a) or 1)
                    num = num + lin_byte(v) * f
                    den = den + f * f
                end
                local c = num / den
                local err = 0
                for _, point in ipairs(use) do
                    local a, v = point[1], point[2]
                    local base = model == "Blinn" and math.cos(a / 2) or math.cos(a)
                    local term = lin_byte(v) - c * S * base ^ k * (nl == 1 and math.cos(a) or 1)
                    err = err + term ^ 2
                end
                if best == nil or err < best[1] then
                    best = {err, k, nl, c, #use}
                end
            end
        end
        say(model, pyish.float_repr(sh), "k", pyish.float_repr(best[2]), "nl", tostring(best[3]),
            string.format("scale %.4f", best[4]), string.format("rms %.5f", (best[1] / best[5]) ^ 0.5))
        for i = 1, math.min(8, #pts) do
            print(string.format("    a=%.2f measured %.4f", pts[i][1], lin_byte(pts[i][2])))
        end
    end
    print("--- the renderer's model: exponent 128 * shininess, times N.L, the view vector from the pixel to the camera")
    local V = norm({0.125, -0.125, 5.0})
    for _, group in ipairs(groups) do
        local model, sh, pts = group.model, group.sh, group.pts
        local worst, err, count = 0, 0, 0
        for _, point in ipairs(pts) do
            local a, v = point[1], point[2]
            local L = {0.0, math.sin(a), math.cos(a)}
            local NdotL = L[3]
            local x
            if model == "Blinn" then
                local H = {L[1] + V[1], L[2] + V[2], L[3] + V[3]}
                local h = math.sqrt(0 + H[1] * H[1] + H[2] * H[2] + H[3] * H[3])
                x = H[3] / h
            else
                local R = {-L[1], -L[2], L[3]}
                x = math.max(0.0, 0 + R[1] * V[1] + R[2] * V[2] + R[3] * V[3])
            end
            local pred = enc_byte(S * x ^ (128 * sh) * NdotL)
            local e = math.abs(pred - v)
            worst = math.max(worst, e)
            err = err + e * e
            count = count + 1
        end
        say(model, "shininess", pyish.float_repr(sh), string.format("rms %.2f levels, worst %d, over %d angles",
            (err / count) ^ 0.5, math.floor(worst), count))
    end
end

local function pbr_rows(dir)
    local rows = {}
    for _, line in ipairs(lines_starting(path.join(dir, "dense.txt"), "pbr ")) do
        local p = pyish.split(line)
        table.insert(rows, {pyish.float(p[2]:sub(7)), pyish.float(p[3]:sub(5)), pyish.float(p[4]:sub(5)),
            pyish.float(p[5]:sub(3)), pyish.float(p[6])})
    end
    return rows
end

local function pbr_model(r, met, alb, a, V, alpha_map, gkind, fkind, diffkind, piscale)
    local N = {0, 0, 1}
    local L = {0, -math.sin(a), math.cos(a)}
    local H = norm({L[1] + V[1], L[2] + V[2], L[3] + V[3]})
    local nl = math.max(dot(N, L), 0)
    local nv = math.max(dot(N, V), 1e-4)
    local nh = math.max(dot(N, H), 0)
    local vh = math.max(dot(V, H), 0)
    local albl = lin_byte(alb * 255)
    local alpha
    if alpha_map == "r2" then
        alpha = r * r
    elseif alpha_map == "r" then
        alpha = r
    else
        alpha = math.max(r * r, 0.002)
    end
    local a2 = alpha * alpha
    local f0 = 0.04 * (1 - met) + albl * met
    local F
    if fkind == "schlick" then
        F = f0 + (1 - f0) * (1 - vh) ^ 5
    else
        F = f0
    end
    local G
    if gkind == "schlick_k2" then
        G = G_schlick(nl, nv, alpha / 2)
    elseif gkind == "schlick_direct" then
        G = G_schlick(nl, nv, (r + 1) ^ 2 / 8)
    else
        G = G_smith_corr(nl, nv, a2)
    end
    local spec = D_ggx(nh, a2) * G * F / math.max(4 * nl * nv, 1e-4) * nl
    if piscale then
        spec = spec * math.pi
    end
    local kd = (1 - met) * (diffkind == "1-F" and (1 - F) or 1)
    local diff = albl * kd * nl
    return (diff + spec) * 0.25
end

local function pbr(dir)
    local rows = pbr_rows(dir)
    local Vs = {
        {"ortho", {0, 0, 1}},
        {"cam", norm({-0.125, -0.125, 5})},
        {"cam2", norm({0.125, 0.125, 5})},
        {"cam3", norm({-0.125, 0.125, 5})},
        {"cam4", norm({0.125, -0.125, 5})},
    }
    local results = {}
    for _, entry in ipairs(Vs) do
        local vname, V = entry[1], entry[2]
        for _, alpha_map in ipairs({"r2", "r"}) do
            for _, gkind in ipairs({"schlick_k2", "schlick_direct", "smith_corr"}) do
                for _, fkind in ipairs({"schlick", "f0"}) do
                    for _, diffkind in ipairs({"1-F", "plain"}) do
                        for _, piscale in ipairs({true, false}) do
                            local combo = {alpha_map, gkind, fkind, diffkind, piscale}
                            local err, n, worst = 0, 0, 0
                            for _, row in ipairs(rows) do
                                local r, met, alb, a, v = row[1], row[2], row[3], row[4], row[5]
                                if v < 254 then
                                    local p = enc_byte(pbr_model(r, met, alb, a, V, alpha_map, gkind, fkind, diffkind, piscale))
                                    local e = math.abs(p - v)
                                    err = err + e * e
                                    n = n + 1
                                    worst = math.max(worst, e)
                                end
                            end
                            table.insert(results, {(err / n) ^ 0.5, worst, vname, combo, n})
                        end
                    end
                end
            end
        end
    end
    table.sort(results, function(x, y)
        if x[1] ~= y[1] then
            return x[1] < y[1]
        end
        if x[2] ~= y[2] then
            return x[2] < y[2]
        end
        if x[3] ~= y[3] then
            return x[3] < y[3]
        end
        for i = 1, 5 do
            if x[4][i] ~= y[4][i] then
                if type(x[4][i]) == "boolean" then
                    return y[4][i]
                end
                return x[4][i] < y[4][i]
            end
        end
        return x[5] < y[5]
    end)
    for i = 1, math.min(8, #results) do
        local b = results[i]
        print(string.format("rms %.2f worst %d V=%s %s n=%d", b[1], math.floor(b[2]), b[3], tuple_repr(b[4]), b[5]))
    end
end

local function graze_rows(dir)
    local rows = {}
    for _, line in ipairs(lines_starting(path.join(dir, "grazing.txt"), "")) do
        local p = pyish.split(line)
        local row = {}
        for i = 2, 6 do
            table.insert(row, pyish.float(p[i]:match("^[^=]*=(.*)$")))
        end
        table.insert(row, pyish.float(p[7]))
        table.insert(rows, row)
    end
    return rows
end

local function graze_pix(t, sy)
    local y = sy * 0.125
    local x = 0.125
    local n = rotx({0, 0, 1}, t)
    local d = (n[2] * y + n[3] * 5) / n[3]
    return {x, y, 5 - d}, n
end

local function graze(dir)
    local rows = graze_rows(dir)
    for _, fk in ipairs({"schlick", "f0"}) do
        for _, sy in ipairs({1, -1}) do
            for _, sx in ipairs({1, -1}) do
                local err, worst, n = 0, 0, 0
                local bad = {}
                for _, row in ipairs(rows) do
                    local t, r, met, alb, la, v = row[1], row[2], row[3], row[4], row[5], row[6]
                    if v < 254 then
                        local P, N = graze_pix(t, sy)
                        P[1] = P[1] * sx
                        local V = norm({-P[1], -P[2], 5 - P[3]})
                        local L = rotx({0, 0, 1}, t + la)
                        local H = norm({L[1] + V[1], L[2] + V[2], L[3] + V[3]})
                        local nl = math.max(dot(N, L), 0)
                        local nv = math.max(dot(N, V), 1e-4)
                        local nh = math.max(dot(N, H), 0)
                        local vh = math.max(dot(V, H), 0)
                        local albl = lin_byte(alb * 255)
                        local alpha = r * r
                        local a2 = alpha * alpha
                        local f0 = 0.04 * (1 - met) + albl * met
                        local F = f0
                        if fk == "schlick" then
                            F = f0 + (1 - f0) * (1 - vh) ^ 5
                        end
                        local G = G_smith_corr(nl, nv, a2)
                        local spec = 0
                        if nl > 0 then
                            spec = D_ggx(nh, a2) * G * F / math.max(4 * nl * nv, 1e-4) * nl * math.pi
                        end
                        local p = enc_byte((albl * (1 - met) * nl + spec) * 0.25)
                        local e = math.abs(p - v)
                        err = err + e * e
                        n = n + 1
                        worst = math.max(worst, e)
                        if e > 2 then
                            table.insert(bad, {t, r, met, alb, la, v, p})
                        end
                    end
                end
                local shown = {}
                for i = 1, math.min(4, #bad) do
                    table.insert(shown, tuple_repr(bad[i]))
                end
                print(fk, "sy", tostring(sy), "sx", tostring(sx),
                    string.format("rms %.2f worst %d n %d", (err / n) ^ 0.5, math.floor(worst), n),
                    "[" .. table.concat(shown, ", ") .. "]")
            end
        end
    end
end

local function selfillumination(dir)
    local sets = {
        none = {0, nil},
        dir0 = {0, {1.0}},
        dir1 = {0, {math.cos(1)}},
        away = {0, {0.0}},
        amb = {1, nil},
        ["amb+dir1"] = {1, {math.cos(1)}},
        ["dir1x0.5"] = {0, {0.5 * math.cos(1)}},
    }
    local function sum_of(list)
        local total = 0
        for _, x in ipairs(list) do
            total = total + x
        end
        return total
    end
    local function model(name, d, s, al, dl, emission)
        emission = emission or 0.0
        if name == "Constant" then
            return d + emission
        end
        local lights = dl == nil and 1.0 or sum_of(dl) + s
        return d * al + d * lights + emission
    end
    local worst, order = {}, {}
    local count = 0
    local base = {}
    local d_half = lin_unit(0.5)
    for line in pyish.lines_of(path.join(dir, "selfillumination.txt")) do
        local p = pyish.split(line)
        if p[2] == "specular" or p[2] == "emission" or p[2] == "intensity0.5" or p[2] == "unlockedambient" then
            local name, term = p[1], p[2]
            local s, px = lin_unit(pyish.float(p[3])), math.tointeger(tonumber(p[4]))
            local d = d_half
            local skip = false
            local c
            if term == "specular" then
                if name == "Blinn" or name == "Phong" then
                    if s == 0 then
                        base[name] = lin_byte(px / 255)
                        skip = true
                    else
                        c = base[name] + d * s
                    end
                else
                    c = model(name, d, s, 0, {math.cos(0.2)})
                end
                if not skip then
                    local e = math.abs(px - pyish.pyround(enc_unit(c) * 255))
                    count = count + 1
                    if worst[name] == nil then
                        table.insert(order, name)
                        worst[name] = 0
                    end
                    worst[name] = math.max(worst[name], e)
                    if e > 1 then
                        print("off by", tostring(e), pyish.strip(line))
                    end
                end
            else
                if term == "emission" then
                    c = model(name, d, s, 0, {math.cos(1)}, lin_unit(0.25))
                elseif term == "intensity0.5" then
                    c = model(name, d, 0.5 * s, 0, {math.cos(1)})
                else
                    if name == "Constant" then
                        c = d
                    else
                        c = lin_unit(0.25) + d * (math.cos(1) + s)
                    end
                end
                local e = math.abs(px - pyish.pyround(enc_unit(c) * 255))
                count = count + 1
                if worst[name] == nil then
                    table.insert(order, name)
                    worst[name] = 0
                end
                worst[name] = math.max(worst[name], e)
                if e > 1 then
                    print("off by", tostring(e), pyish.strip(line))
                end
            end
        else
            local name = p[1]
            local d = lin_unit(pyish.float(p[2]))
            local s = lin_unit(pyish.float(p[3]))
            local lights = p[4]
            local px = math.tointeger(tonumber(p[5]))
            local c = model(name, d, s, sets[lights][1], sets[lights][2])
            local e = math.abs(px - pyish.pyround(enc_unit(c) * 255))
            count = count + 1
            if worst[name] == nil then
                table.insert(order, name)
                worst[name] = 0
            end
            worst[name] = math.max(worst[name], e)
            if e > 1 then
                print("off by", tostring(e), pyish.strip(line))
            end
        end
    end
    local values = {}
    for _, name in ipairs(order) do
        table.insert(values, tostring(worst[name]))
    end
    print(tostring(count) .. " pixels; worst per model " .. dict_repr(order, values))
end

function main(command, dir)
    if command == "spec" then
        spec(dir)
    elseif command == "pbr" then
        pbr(dir)
    elseif command == "graze" then
        graze(dir)
    elseif command == "selfillumination" then
        selfillumination(dir)
    else
        io.stderr:write("usage: fits.lua spec|pbr|graze|selfillumination <build-dir>\n")
        os.exit(2)
    end
end
