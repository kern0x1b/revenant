import("fixtures")

local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local function with_env(variables, action)
    local saved = {}
    for name, value in pairs(variables) do
        saved[name] = os.getenv(name)
        os.setenv(name, value)
    end
    local result
    local message = fixtures.refusal(function () result = action() end)
    for name in pairs(variables) do
        os.setenv(name, saved[name] or "")
    end
    if message then
        raise(message)
    end
    return result
end

function failures(arguments)
    local found = {}
    local folder = fixtures.scratch()
    local store = path.join(folder, "store")
    local cache = path.join(folder, "cache")
    local digest = "0123456789abcdef"

    local shared = with_env({REVENANT_STORE = store, REVENANT_CACHE = cache}, function () return lowered.shared_overlay_folder(digest) end)
    if shared ~= path.join(store, "lowered", digest) then
        table.insert(found, "the overlay of a digest is a folder of the shared store, not of the cache of the checkout: " .. tostring(shared))
    end

    local moved = with_env({REVENANT_STORE = path.join(folder, "other"), REVENANT_CACHE = cache}, function () return lowered.shared_overlay_folder(digest) end)
    if moved == shared or moved ~= path.join(folder, "other", "lowered", digest) then
        table.insert(found, "REVENANT_STORE moves the overlay folder with it: " .. tostring(moved))
    end
    return found
end
