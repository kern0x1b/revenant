import("core.base.json")

function failures(opt)
    local rust = import("rust", {rootdir = opt.modules, anonymous = true})
    local found = {}
    if rust.triple() ~= "armv7-apple-ios6" then
        table.insert(found, "the Rust rule builds armv7-apple-ios6, and names " .. rust.triple())
    end
    local spec = json.decode(io.readfile(rust.spec()))
    for key, wanted in pairs({os = "ios", arch = "arm", vendor = "apple", ["target-pointer-width"] = 32,
                              ["llvm-target"] = "thumbv7-apple-ios", ["llvm-floatabi"] = "soft", abi = "eabi",
                              cpu = "generic", ["has-thread-local"] = false, ["panic-strategy"] = "abort"}) do
        if spec[key] ~= wanted then
            table.insert(found, string.format("the armv7 iOS 6 spec must say %s is %s, and says %s", key, tostring(wanted), tostring(spec[key])))
        end
    end
    if spec["llvm-target"]:find("ios%d") then
        table.insert(found, "the spec's llvm-target must not carry a deployment version: rustc adds the one it knows, so a versioned triple is refused")
    end
    return found
end
