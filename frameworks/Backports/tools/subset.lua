local TARGETS = {RevenantCoding = true, RevenantCKWebAuth = true}

local PACKAGES = {
    ["lzfse"] = {"revenant@lzfse lzfse-1.0"},
    ["zlib"] = {"revenant@zlib v1.3.2"},
    ["lz4"] = {"revenant@lz4 v1.9.2"},
    ["xz"] = {"revenant@xz v5.8.4"},
    ["box2d"] = {"revenant@box2d 2.2.1"},
    ["micro-ecc"] = {"revenant@micro-ecc"},
    ["boringssl"] = {"revenant@boringssl"},
    ["monocypher"] = {"revenant@monocypher 4.0.2"},
    ["suitesparse-ordering"] = {"revenant@suitesparse-ordering v7.12.2"},
    ["ggml"] = {"revenant@ggml 0.25.3"},
    ["zxing-cpp"] = {"revenant@zxing-cpp v3.1.1"},
    ["tesseract"] = {"revenant@tesseract 5.5.3"},
    ["leptonica"] = {"revenant@leptonica 1.85.0"},
    ["tessdata"] = {"revenant@tessdata", {languages = "eng,rus,ukr"}},
    ["libcxx"] = {"revenant@libcxx"},
    ["ffmpeg-hevc"] = {"revenant@ffmpeg-hevc"},
    ["apple-compat"] = {"revenant@apple-compat"},
}

function backports_subset(rows, selected)
    if selected == nil then
        return rows
    end
    local byname = {}
    for _, library in ipairs(rows) do
        byname[library.name] = library
    end
    local keep, pending = {}, selected:split("%s*,%s*")
    while #pending > 0 do
        local name = table.remove(pending)
        if not keep[name] then
            local library = byname[name] or raise("REVENANT_BACKPORTS_LIBRARIES names %s, which is no Backports library", name)
            keep[name] = true
            for _, dependency in ipairs(library.libraries) do
                if dependency:endswith("Backports") then
                    table.insert(pending, dependency)
                end
            end
        end
    end
    local kept = {}
    for _, library in ipairs(rows) do
        if keep[library.name] then
            table.insert(kept, library)
        end
    end
    return kept
end

function backports_is_target(name)
    return TARGETS[name] == true
end

function backports_uses(rows, target)
    for _, library in ipairs(rows) do
        if table.contains(library.archives, target) then
            return true
        end
    end
    return false
end

function backports_requires(rows)
    local out, seen = {}, {}
    for _, library in ipairs(rows) do
        for _, name in ipairs(library.archives) do
            if not backports_is_target(name) and not seen[name] then
                local spec = PACKAGES[name] or raise("%s uses package %s, which subset.lua does not require", library.name, name)
                seen[name] = true
                table.insert(out, {name = name, requirement = spec[1], configs = spec[2]})
            end
        end
    end
    return out
end
