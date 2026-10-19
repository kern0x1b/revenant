import("core.base.option")
import("@self.packaging")

function main()
    packaging.write({target = option.get("target"), outputdir = option.get("outputdir")})
end
