if os.getenv("RN_DEPS_REPO") then
    add_requires("revenant@folly 2024.11.18.00", {alias = "folly"})
    add_requires("revenant@socketrocket 0.7.1", {alias = "socketrocket"})
end

includes("targets/core.lua")
