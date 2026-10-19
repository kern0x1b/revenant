-- `verify`: the round trips of an sdk run alone (the sdk command's --verify step, design-sdk-generator.md step 4): decls over the generated
-- headers against the full IR, and the Swift round trip, under --out. --framework runs one framework (a measurement; the sdk command
-- runs them all). Needs --sdk, --tree, --ir (the full IR), --headers (the generated headers tree), --coordination (the folder heavy.sh
-- sits in) and --out. Returns the exit status: 1 when a decls run fails, else 0.

-- Returns the exit status.
function run(args)
    local status, detail = import("verify", {anonymous = true}).run(args)
    print("verify: " .. tostring(detail))
    return status
end
