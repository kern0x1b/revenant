includes("../../modules/emulator_source.lua")

add_requires("revenant@emulator", {alias = "emulator", configs = requirement_configs(path.join(os.scriptdir(), "../../.."))})
add_requires("revenant@swiftshader", {alias = "swiftshader"})
add_requires("revenant@emulator-guest", {alias = "emulator-guest"})
