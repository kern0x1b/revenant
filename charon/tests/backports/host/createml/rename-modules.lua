-- rename-modules.lua: the module renaming run.sh makes in a copy of the port's CreateML sources, so that
-- Apple's CreateML and the port's can be held in one process (run.sh's header says why). It rewrites
-- every .swift file under the folder given: every whole word `CreateMLComponents` becomes
-- `PortCreateMLComponents`, and an `import CoreML` line becomes `import PortCoreML`, except in the
-- CoreML folder itself, whose self-import stays as it is. Usage:
--     xmake l tests/backports/host/createml/rename-modules.lua <files folder>
function main(root)
    for _, file in ipairs(os.files(path.join(root, "**.swift"))) do
        local text = io.readfile(file)
        -- The whole word, not the import line: the port's sources qualify their own types with the
        -- module's name, and a half-renamed copy would not compile. The `CoreML` import goes the same
        -- way, and it has to: the linear models are written against the port's own shaped-array
        -- overlay, and a copy left importing the host's `CoreML` would fit over the host's
        -- `MLShapedArray` and the comparison would be of the host against itself.
        assert(not text:find("PortCreateMLComponents", 1, true), file)
        assert(not text:find("PortCoreML", 1, true), file)
        text = text:gsub("%f[%w_]CreateMLComponents%f[^%w_]", "PortCreateMLComponents")
        -- The overlay's own sources keep `import CoreML`: it is the self-import the module makes when the
        -- header has already given it what it needs, and rewriting it here would leave the module
        -- importing a name of its own and seeing nothing.
        if path.filename(path.directory(file)) ~= "CoreML" then
            text = renameCoreMLImports(text)
        end
        io.writefile(file, text)
    end
end

-- Every `import CoreML` line of a file, whole. A pass replaces the lines whose newline is still there,
-- and the next pass catches the one that followed, since a match consumes the newline before it.
function renameCoreMLImports(text)
    text = "\n" .. text
    local changed = true
    while changed do
        local count
        text, count = text:gsub("\nimport CoreML\n", "\nimport PortCoreML\n")
        changed = count > 0
    end
    text = text:gsub("\nimport CoreML$", "\nimport PortCoreML")
    return text:sub(2)
end
