function main()
    local digest = import("digest", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
    local root = path.join(os.scriptdir(), "..", "..")
    for _, recipe in ipairs(digest.recipes()) do
        io.writefile(path.join(root, recipe.folder, "digest.lua"), digest.digest_file(recipe, digest.sources(root, recipe.inputs)))
        print("wrote %s", path.join(recipe.folder, "digest.lua"))
    end
end
