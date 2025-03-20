--- Terminal cursor management module.
-- Provides utilities to the cursor in terminals.
-- @module terminal.cursor
local M = {}
package.loaded["terminal.cursor"] = M -- Register the module early to avoid circular dependencies
M.visible = require "terminal.cursor.visible"
M.shape = require "terminal.cursor.shape"

return M
