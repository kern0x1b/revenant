package("tessdata")
    set_homepage("https://github.com/tesseract-ocr/tessdata_best")
    set_description("The Tesseract 5 models of Vision's text recognition: tessdata_fast and tessdata_best for the languages the languages config names, each copied from the checkout of its pinned commit and checked by sha256")
    set_license("Apache-2.0")

    local FAST_COMMIT = "87416418657359cb625c412a48b6e1d6d41c29bd"
    local BEST_COMMIT = "e12c65a915945e4c28e237a9b52bc4a8f39a0cec"
    local LICENSE_SHA256 = "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"

    add_urls("https://github.com/tesseract-ocr/tessdata_best.git")
    add_versions("2024.03.09", BEST_COMMIT)
    add_resources("2024.03.09", "tessdata_fast", "https://github.com/tesseract-ocr/tessdata_fast.git", FAST_COMMIT)

    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    add_configs("recipe", {description = "The digest of this recipe, so a changed model list or install step is a different package.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FAST = {
        {"deu", "19d219bbb6672c869d20a9636c6816a81eb9a71796cb93ebe0cb1530e2cdb22d"},
        {"eng", "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2"},
        {"fra", "ced037562e8c80c13122dece28dd477d399af80911a28791a66a63ac1e3445ca"},
        {"ita", "b8f89e1e785118dac4d51ae042c029a64edb5c3ee42ef73027a6d412748d8827"},
        {"por", "c4932b937207a9514b7514d518b931a99938c02a28a5a5a553f8599ed58b7deb"},
        {"spa", "6f2e04d02774a18f01bed44b1111f2cd7f3ba7ac9dc4373cd3f898a40ea6b464"}
    }

    local BEST = {
        {"ara", "ab9d157d8e38ca00e7e39c7d5363a5239e053f5b0dbdb3167dde9d8124335896"},
        {"ces", "d821773116d3c4e0360ea750066436c60ae45af02c39da3a840a543d761b3f41"},
        {"chi_sim", "4fef2d1306c8e87616d4d3e4c6c67faf5d44be3342290cf8f2f0f6e3aa7e735b"},
        {"chi_tra", "1aa60488574cafa69486d919284f079ca9b68fcc7f6ad8dc1ff1b318dfd97028"},
        {"dan", "28901bf4b58a657b511fddafce4ce245a1f21c5ee075734b479d01ab8d4cb6a5"},
        {"deu", "8407331d6aa0229dc927685c01a7938fc5a641d1a9524f74838cdac599f0d06e"},
        {"eng", "8280aed0782fe27257a68ea10fe7ef324ca0f8d85bd2fd145d1c2b560bcb66ba"},
        {"fin", "96745dd0900fe997541516863d859616df6120430db546424feae72923828423"},
        {"fra", "907743d98915c91a3906dfbf6e48b97598346698fe53aaa797e1a064ffcac913"},
        {"hin", "bd2e65a2184af08a167b0be2439e91fa5edbc4394399ca2f692b843ae26e78d6"},
        {"ind", "1f6596041ffb4cd5094e5f98764db43cfde04edb8f02b988f90ebc1353ac73b8"},
        {"ita", "8df9c89176fb93f56bf4b2d4ede04c01c1f31d4b7697fbd76cc336df700f3f38"},
        {"jpn", "36bdf9ac823f5911e624c30d0553e890b8abc7c31a65b3ef14da943658c40b79"},
        {"kor", "f888d4038348a0c3d25151e7f452bda0d74ca275b18cab146798bcbb94084fff"},
        {"mar", "799405456528ffd688bc8173ea9179c0646120436ac35099dccb175c4c70f652"},
        {"msa", "2fa693701d2fb3685cf3e0a64bc1bfb97d66a50f93c07b2ebc0ff360ea62621f"},
        {"nld", "92e7a1ad4bf8082e268de57c7823316ec024935702c6ed2a1e473b3a071aa733"},
        {"nor", "451d52ba1559aa1aecf163ccbfdeced2b9605fbd49480f5e8a53ace29b9eb0e7"},
        {"pol", "e80cc4cefbdface06e9223f43f089556b9dcf104020fbc0a200f6863c57d4405"},
        {"por", "711de9dbb8052067bd42f16b9119967f30bada80d57e2ef24f65d09f531adb04"},
        {"ron", "93588d7e59a28fad7920db07767345438ee5eeefa3c5f20541dfb9ad083a6d2e"},
        {"rus", "b617eb6830ffabaaa795dd87ea7fd251adfe9cf0efe05eb9a2e8128b7728d6b6"},
        {"spa", "e2c1ffdad8b30f26c45d4017a9183d3a7f9aa69e59918be4f88b126fac99ab2c"},
        {"swe", "360303308aa5d4a912ac3b3637691152b7532d9bd6e960639db1affb83db7ea9"},
        {"tha", "ee8adab6dc69eb8df3d3c8307ae8295471b7bd7d86a06d9267aa8f479b064eac"},
        {"tur", "e0c3338dc17503dc7d335a507c9ae01b2b46cfd07561171e1e1ac55d85e8e438"},
        {"ukr", "1277f6e3b6f707063a92d40e7678e7f57154e8414e328e340be9ee9275eea9c8"},
        {"vie", "b6b49293d95d0b6dbd8780174627e82c75be957b6f4ed9862155540d6b00bb45"}
    }

    local DEFAULT = "eng,rus,ukr"

    add_configs("languages", {description = "The Tesseract codes whose models are installed, comma separated, or all. Each code is installed at the fast level where tessdata_fast has its model and at the accurate level where tessdata_best has it.",
                              default = DEFAULT, type = "string"})

    local function find_model(models, code)
        for _, model in ipairs(models) do
            if model[1] == code then
                return model
            end
        end
    end

    local function chosen(package)
        local value = package:config("languages") or DEFAULT
        local codes = {}
        if value == "all" then
            for _, model in ipairs(BEST) do
                table.insert(codes, model[1])
            end
        else
            for code in value:gmatch("[^,%s]+") do
                table.insert(codes, code)
            end
        end
        for _, code in ipairs(codes) do
            if not find_model(FAST, code) and not find_model(BEST, code) then
                raise("tessdata has no model for %s", code)
            end
        end
        return codes
    end

    on_install(function (package)
        local function copy(source, file, sha256)
            if hash.sha256(source) ~= sha256 then
                raise("%s does not match its pinned sha256", source)
            end
            os.cp(source, file)
        end
        local best = os.curdir()
        local fast = package:resourcedir("tessdata_fast")
        local function install(level, checkout, model)
            local folder = path.join(package:installdir("share"), "tessdata", level)
            os.mkdir(folder)
            copy(path.join(checkout, model[1] .. ".traineddata"), path.join(folder, model[1] .. ".traineddata"), model[2])
        end
        for _, code in ipairs(chosen(package)) do
            local fast_model, best_model = find_model(FAST, code), find_model(BEST, code)
            if fast_model then
                install("fast", fast, fast_model)
            end
            if best_model then
                install("best", best, best_model)
            end
        end
        os.mkdir(package:installdir("licenses"))
        copy(path.join(fast, "LICENSE"), path.join(package:installdir("licenses"), "LICENSE"), LICENSE_SHA256)
    end)

    on_test(function (package)
        for _, code in ipairs(chosen(package)) do
            if find_model(FAST, code) then
                assert(os.isfile(path.join(package:installdir("share"), "tessdata", "fast", code .. ".traineddata")))
            end
            if find_model(BEST, code) then
                assert(os.isfile(path.join(package:installdir("share"), "tessdata", "best", code .. ".traineddata")))
            end
        end
    end)
