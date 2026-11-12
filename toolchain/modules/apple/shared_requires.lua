function lines(sdk)
    local configs = "{configs = {shared = true, apple_sdk = \"" .. sdk .. "\"}}"
    return {
        "add_requireconfs(\"swift-runtime\", {configs = {shared = true}})",
        "add_requireconfs(\"libcxx\", {configs = {packaged = true}})",
        "add_requireconfs(\"**.libcxx\", {configs = {packaged = true}})",
        "add_requireconfs(\"swiftui\", " .. configs .. ")",
        "add_requireconfs(\"**.swiftui\", " .. configs .. ")",
        "add_requireconfs(\"swift-crypto\", " .. configs .. ")",
        "add_requireconfs(\"**.swift-crypto\", " .. configs .. ")"}
end
