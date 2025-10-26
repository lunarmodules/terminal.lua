local package_name = "luarocket"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "Tieske"
local github_repo_name = "luarocket"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "Terminal UI for LuaRocks",
  detailed = [[
    Cross platform Terminal UI for LuaRocks.
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
  "luasystem >= 0.6.3",
  "utf8 >= 1.3.0",
  "copas-async",
}

build = {
  type = "builtin",

   install = {
      bin = {
          luarocket = "bin/luarocket.lua",
      }
   },

  modules = {
    ["luarocket.main"] = "src/main.lua",
    ["luarocket.luarocks"] = "src/luarocks.lua",
    ["luarocket.json-encode"] = "src/json-encode.lua",
  },

  copy_directories = {
    -- can be accessed by `luarocks terminal doc` from the commandline
    -- "docs",
  },
}
