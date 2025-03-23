--- Terminal text module.
-- Provides utilities to set text attributes in terminals.
-- @module terminal.text
local M = {}
package.loaded["terminal.text"] = M -- Register the module early to avoid circular dependencies

M.color = require("terminal.text.color")


-- local output = require("terminal.output")
-- local utils = require("terminal.utils")



return M
