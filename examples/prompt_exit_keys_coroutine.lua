--- Example: exit-key behaviour with coroutines (mechanism over policy).
--
-- Demonstrates:
--   - Configurable exit keys (Enter, Escape, Tab) — prompt returns (value, key), caller decides meaning.
--   - Tab = focus change: prompt yields, caller resumes later with value preserved.
--   - No library changes: uses terminal.input + keymap + EditLine. (terminal.cli.prompt does not
--     yet support exit_keys or (value, key) return; this minimal loop shows the intended pattern.)
--
-- Run from repo root: lua examples/prompt_exit_keys_coroutine.lua

package.path = package.path .. ";src/?.lua;src/?/init.lua"
local t = require("terminal")
local EditLine = require("terminal.editline")
local keymap = t.input.keymap.get_keymap()
local keys = t.input.keymap.default_keys

-- Same editing actions as Prompt (subset we need)
local keyname2actions = {
  ["ctrl_?"] = "backspace", ["left"] = "left", ["right"] = "right",
  ["home"] = "goto_home", ["end"] = "goto_end",
  ["ctrl_h"] = "backspace", ["ctrl_a"] = "goto_home", ["ctrl_e"] = "goto_end",
  ["ctrl_u"] = "backspace_to_start", ["ctrl_k"] = "delete_to_end", ["ctrl_d"] = "delete",
}

local PROMPT_STR = "> "
local MAX_LEN = 80

--- Build exit-keys set: Enter, Escape, Tab (key names from default_keys).
local exit_keys = {
  [keys.enter] = true,
  [keys.escape] = true,
  [keys.tab] = true,
}

--- Draw prompt and line; position cursor after prompt + cursor-in-value.
local function draw(prompt_str, line)
  t.output.write(t.cursor.position.column_seq(1))
  t.output.write(prompt_str)
  t.output.write(tostring(line))
  t.output.write(t.clear.eol_seq())
  t.output.write(t.cursor.position.left_seq(line:len_col() - line:pos_col()))
end

--- Minimal prompt loop: exit keys end input and return (value, key_name).
-- On Tab, yields (value, keys.tab); on resume, receives preserved value and continues.
-- Uses EditLine for the buffer; no policy (submit/cancel) — caller interprets key.
local function prompt_loop(initial_value)
  local line = EditLine({ value = initial_value or "", position = 1 })
  line:goto_end()

  while true do
    draw(PROMPT_STR, line)
    local rawkey, keytype = t.input.readansi(math.huge)
    if not rawkey then
      return nil, keytype
    end

    local keyname = keymap[rawkey] or rawkey

    if exit_keys[keyname] then
      -- Mechanism: return value + key; caller decides policy.
      if keyname == keys.tab then
        local preserved = tostring(line)
        local resumed_value = coroutine.yield(preserved, keyname)
        if resumed_value ~= nil then
          line = EditLine({ value = resumed_value, position = 1 })
          line:goto_end()
        end
      else
        if keyname == keys.escape then
          return nil, keyname
        end
        return tostring(line), keyname
      end
    end

    local action = keyname2actions[keyname]
    if action then
      local method = line[action]
      if method then method(line) end
    elseif keytype == "char" and line:len_char() < MAX_LEN and rawkey and #rawkey >= 1 then
      local ok = pcall(function() line:insert(rawkey) end)
      if not ok then t.bell() end
    else
      t.bell()
    end
  end
end

--- Run prompt inside a coroutine; on Tab yield, on Enter/Escape return and exit.
local function main()
  t.output.print("Exit keys: Enter = submit, Escape = cancel, Tab = focus change (yield).")
  t.output.print("")

  local co = coroutine.create(prompt_loop)
  local value, key = nil, nil
  local initial = ""

  while true do
    local ok, v1, v2 = coroutine.resume(co, initial)
    if not ok then
      t.output.print("Error: " .. tostring(v1))
      break
    end
    if coroutine.status(co) == "dead" then
      value, key = v1, v2
      break
    end
    -- Tab: yielded (value, keys.tab); simulate focus change, then resume with same value.
    value, key = v1, v2
    t.output.print("")
    t.output.print("[Focus changed (Tab); resuming with value preserved]")
    t.output.print("")
    initial = value
  end

  t.output.print("")
  -- Policy in caller: interpret key.
  if key == keys.enter then
    t.output.print("Submitted: '" .. (value or "") .. "'")
  elseif key == keys.escape then
    t.output.print("Cancelled.")
  else
    t.output.print("Exit key: " .. tostring(key) .. " -> value: '" .. tostring(value) .. "'")
  end
end

t.initwrap(main, { displaybackup = false, filehandle = io.stdout })()
