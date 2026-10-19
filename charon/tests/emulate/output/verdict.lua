-- verdict.lua: what a run's verdict.json says, read by output.sh.
--
--   xmake l tests/emulate/output/verdict.lua <verdict.json> runner
--       prints "tree" when the runner that wrote the verdict is the tree's own (its top-level output is 1), and
--       "installed" otherwise
--   xmake l tests/emulate/output/verdict.lua <verdict.json> <key>
--       prints the value of that top-level key, or nothing when the key is absent
--
-- A file that is not JSON stops the run with an error, which output.sh reports as "unknown" for the runner.

import("core.base.json")

function main(file, what)
    local document = json.decode(io.readfile(file))
    if what == "runner" then
        print(document.output == 1 and "tree" or "installed")
    else
        local value = document[what]
        if type(value) == "number" and value == math.floor(value) then
            value = string.format("%d", value)
        end
        print(value == nil and "" or tostring(value))
    end
end
