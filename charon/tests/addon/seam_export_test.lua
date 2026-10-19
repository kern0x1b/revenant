-- seam_export_test.lua: does the gate keep a declared seam exported, and only the declared ones?
--
-- A seam is a charon_ function a library defines for another library of the package to link against.
-- internal_symbol() keeps every charon_ name out of the surface and the registry check, so a seam
-- needs no registry row; link() would hide it from the dylib, which is what made the Swift Network
-- module unable to link its interface lookup. seam_symbols() is what link() reads to tell a seam from
-- the rest of the internal names, and this test is the check that it reads the declaration and no more.
--
-- The fixture is a library folder of its own, so the check is on the reading and not on any library
-- of the package: a #define of the macro, a declaration in a header and a definition in a source file,
-- a function that is not a seam, and a name in a comment that is not a declaration.

import("fixtures")

function main()
    local root = os.scriptdir() .. "/../.."
    local backports = import("apple.backports", {rootdir = path.join(root, "modules"),
                                                anonymous = true})
    local folder = fixtures.scratch()
    local library = {name = "FixtureBackports", folder = "Fixture"}
    local sources = path.join(folder, library.folder)
    os.mkdir(sources)
    io.writefile(path.join(sources, "Seam.h"), table.concat({
        "#define CHARON_SEAM __attribute__((visibility(\"default\")))",
        "CHARON_SEAM int charon_declared_seam(const char *name);",
        "int charon_plain_function(const char *name);",
        "/* CHARON_SEAM int charon_named_in_a_comment(void); */",
    }, "\n") .. "\n")
    io.writefile(path.join(sources, "Seam.m"), table.concat({
        "CHARON_SEAM int charon_declared_seam(const char *name)",
        "{",
        "    return 0;",
        "}",
        "CHARON_SEAM static int charon_static_seam(void);",
    }, "\n") .. "\n")

    local found = backports.seam_symbols(folder, library)
    local failures = {}
    if not found["_charon_declared_seam"] then
        table.insert(failures, "the declared seam charon_declared_seam is not read from its header and its definition")
    end
    if found["_charon_plain_function"] or found["_charon_named_in_a_comment"] then
        table.insert(failures, "a function without CHARON_SEAM, or a name in a comment, is read as a seam")
    end
    if found["_CHARON_SEAM"] or found["_visibility"] or found["_attribute__"] then
        table.insert(failures, "the #define of CHARON_SEAM is read as a declaration")
    end
    local count = 0
    for _ in pairs(found) do
        count = count + 1
    end
    if count ~= 2 then
        table.insert(failures, string.format("%d seams read, want 2 (charon_declared_seam and charon_static_seam)", count))
    end
    if #failures > 0 then
        for _, failure in ipairs(failures) do
            print("FAIL: " .. failure)
        end
        raise("%d seam reading failure(s)", #failures)
    end
    print("seam_export: a declared seam is read, and nothing else is")
    return true
end
