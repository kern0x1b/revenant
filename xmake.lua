set_project("hades")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

add_repositories("hades-third-party third_party")

includes("*/xmake.lua")
