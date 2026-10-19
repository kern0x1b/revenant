-- `worklist`: the work list of an sdk run alone (the sdk command's step 3d, design-sdk-generator.md): one module-by-module TSV per framework and
-- totals.tsv under --out, tied to the scope's v-gen-scope.tsv (--scope). Needs the SDK (--sdk), the repository (--tree), the corpus
-- (--coordination) and that scope file. The sdk command runs it after scope; this command runs it again without the parse and the render
-- (a debugging step, like the others). Returns the exit status: 0 when the counts tie to the scope, else 1.

-- Returns the exit status.
function run(args)
    local status, detail = import("worklist", {anonymous = true}).run(args)
    print("worklist: " .. tostring(detail))
    return status
end
