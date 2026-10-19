-- hades: one xmake project over its members.
--
-- Each member that builds with xmake has an xmake.lua at its top, and this file includes them all: their targets are
-- one graph, a member uses another's target with add_deps, and `xmake` at the top builds everything. Third-party code
-- comes as packages from third_party (an xmake package repository: an upstream pin plus our patches per package),
-- never as a copy in a member.
set_project("hades")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

add_repositories("hades-third-party third_party")

includes("*/xmake.lua")
