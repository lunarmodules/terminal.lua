--- CLI component module.
-- Provide CLI widgets for terminal applications
-- NOTE: you MUST `terminal.initialize()` before calling these widgets' `:run()`
-- @module terminal.cli
local M = {}
package.loaded["terminal.cli"] = M -- Register the module early to avoid circular dependencies
M.select = require "terminal.cli.select"
M.prompt = require "terminal.cli.prompt"

return M
