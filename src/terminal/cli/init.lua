--- CLI component module.
-- Provides utilities to handle the cursor in terminals.
-- @module terminal.cli
local M = {}
package.loaded["terminal.cli"] = M -- Register the module early to avoid circular dependencies
M.select = require "terminal.cli.select"
M.prompt = require "terminal.cli.prompt"

return M
