local package_name = "terminal"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "Tieske"
local github_repo_name = "terminal.lua"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "Cross platform terminal library for Lua (Windows/Unix/Mac)",
  detailed = [[
    Cross platform terminal library for Lua (Windows/Unix/Mac)
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
  "luasystem >= 0.5.0",
}

build = {
  type = "builtin",

  modules = {
    ["terminal.init"] = "src/terminal/init.lua",
    ["terminal.width"] = "src/terminal/width.lua",
    ["terminal.progress"] = "src/terminal/progress.lua",
    ["terminal.sequence"] = "src/terminal/sequence.lua",
    ["terminal.input"] = "src/terminal/input.lua",
    ["terminal.output"] = "src/terminal/output.lua",
    ["terminal.clear"] = "src/terminal/clear.lua",
    ["terminal.scroll"] = "src/terminal/scroll.lua",
    ["terminal.color"] = "src/terminal/color.lua",
    ["terminal.color.stack"] = "src/terminal/stack/color.lua"
  },

  copy_directories = {
    -- can be accessed by `luarocks terminal doc` from the commandline
    "docs",
  },
}
