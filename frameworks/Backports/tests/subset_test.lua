local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local subset = import("subset", {rootdir = tools, anonymous = true})
local list = import("library_list", {rootdir = tools, anonymous = true})

local function failure_of(action)
    local message
    try
    {
        action,
        catch
        {
            function (errors)
                message = tostring(errors)
            end
        }
    }
    return message
end

local function names_of(rows)
    local out = {}
    for _, row in ipairs(rows) do
        table.insert(out, row.name)
    end
    table.sort(out)
    return out
end

local function has(list, name)
    return table.contains(list, name)
end

local function expect(found, label, got, want)
    local a, b = table.concat(got, ","), table.concat(want, ",")
    if a ~= b then
        table.insert(found, string.format("%s: got [%s], want [%s]", label, a, b))
    end
end

function main()
    local found = {}
    local every = list.backports_libraries()
    local uikit = subset.backports_subset(every, "UIKitBackports")
    local uikit_names = names_of(uikit)

    expect(found, "a subset of UIKitBackports installs its own packages", names_of(subset.backports_requires(uikit)),
        {"apple-compat", "box2d"})
    if not has(uikit_names, "GraphicsBackports") or not has(uikit_names, "FoundationBackports") then
        table.insert(found, "UIKitBackports does not select the libraries it uses: " .. table.concat(uikit_names, ","))
    end
    if has(uikit_names, "NetworkBackports") or has(uikit_names, "CloudKitBackports") then
        table.insert(found, "UIKitBackports selects libraries it does not use: " .. table.concat(uikit_names, ","))
    end

    local notifications = subset.backports_subset(every, "UserNotificationsUIBackports,UIKitBackports")
    expect(found, "UserNotificationsUIBackports with UIKitBackports installs the same packages as UIKitBackports alone",
        names_of(subset.backports_requires(notifications)), {"apple-compat", "box2d"})
    local with_notifications = table.join(uikit_names, {"UserNotificationsUIBackports"})
    table.sort(with_notifications)
    expect(found, "UserNotificationsUIBackports with UIKitBackports selects UIKitBackports's libraries and itself",
        names_of(notifications), with_notifications)

    local cloudkit = subset.backports_subset(every, "CloudKitBackports")
    expect(found, "CloudKitBackports needs micro-ecc, and not the project's own RevenantCKWebAuth",
        names_of(subset.backports_requires(cloudkit)), {"micro-ecc"})
    if not subset.backports_uses(cloudkit, "RevenantCKWebAuth") or subset.backports_uses(uikit, "RevenantCKWebAuth") then
        table.insert(found, "only the selections that link RevenantCKWebAuth must define its target")
    end

    local full = {}
    for _, row in ipairs(subset.backports_requires(subset.backports_subset(every, nil))) do
        table.insert(full, row.name)
    end
    table.sort(full)
    expect(found, "the full table requires every package the hand-written list required, and apple-compat",
        full, {"apple-compat", "boringssl", "box2d", "ffmpeg-hevc", "ggml", "leptonica", "libcxx", "lz4", "lzfse",
               "micro-ecc", "monocypher", "suitesparse-ordering", "tessdata", "tesseract", "xz", "zlib", "zxing-cpp"})
    for _, row in ipairs(subset.backports_requires(every)) do
        if not row.requirement:startswith("revenant@") then
            table.insert(found, row.name .. " is not required from revenant: " .. row.requirement)
        end
    end

    local message = failure_of(function () subset.backports_subset(every, "NoSuchBackports") end)
    if not message or not message:find("no Backports library", 1, true) then
        table.insert(found, "an unknown library must be refused, and it failed with: " .. tostring(message))
    end

    if #found > 0 then
        raise("%s", table.concat(found, "\n"))
    end
end
