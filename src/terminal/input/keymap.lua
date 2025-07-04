--- Module to map received input to key-names.
-- Check the examples below for usage.
--
-- **key-map**:
-- a `key-map` is a table that maps raw key-stroke input (from `readansi`) to key-names.
-- The raw input can be a control-character (bytes 0-31 + 127), or an ANSI escape sequence.
--
-- note: a raw-key only maps to 1 name, even if the sequence is known under multiple names.
-- For example, the raw key `"\013"` (carriage return) maps to the name `"ctrl_m"`. Though on
-- Windows it is also know as keyname `"enter"` or `"return"`, it will not map to these names.
--
-- That's why there is **keys**:
-- a `map` of aliases for key-names to official key-names. This allows to use user-friendly names for keys.
-- For example, the key-name `"ctrl_m"` can be aliased to `"enter"` or `"return"`, so that
-- you can use these names in your code, instead of the raw key-name. For unknown keys,
-- an error will be thrown, so you can catch typos in your code early.
--
-- So in key-map; raw-key `"\013"` maps to `"ctrl_m"`
--
-- In `keys`; the keys `"ctrl_m"`, `"enter"`, and `"return"`, all map to the same key-name; `"ctrl_m"`.
--
-- Check the source code for default keys and aliases. Custom maps can be created with
-- `get_keymap` and `get_keys`.
-- @usage
-- local rawkey = "\013" -- carriage return
-- local keymap = terminal.input.keymap.default_key_map
-- local keys = terminal.input.keymap.default_keys
--
-- local keyname = key_map[rawkey] --> "ctrl_m"
--
-- -- the following if statements are equivalent:
-- if keyname == "ctrl_m" then     -- uses magic strings, typos are lurking bugs!
-- if keyname == keys.ctrl_m then  -- uses the official name, prevents typos, hard to read
-- if keyname == keys.enter then   -- uses alias, easily readable, prevents typos
-- if keyname == keys.return then  -- uses alias, easily readable, prevents typos
--
-- -- This will throw an error when running due to the typo:
-- if keyname == keys.retunr then  -- typo, will throw an error
-- @module terminal.input.keymap

local M = {}
local sys = require("system")


--- Key-map of only control characters.
-- The control characters are single byte strings, with byte values 0-31 and 127.
-- The map maps the raw control character to a key-name.
-- The key-names are the names of the control characters, e.g. `"ctrl_a"` for byte 1, or
-- `"ctrl_["` for byte 27 (ESC).
-- @table control_characters
M.control_characters = {}
M.control_characters = { -- workaround LDoc bug
  ["\000"] = "ctrl_@", -- null
  ["\001"] = "ctrl_a",
  ["\002"] = "ctrl_b",
  ["\003"] = "ctrl_c",
  ["\004"] = "ctrl_d",
  ["\005"] = "ctrl_e",
  ["\006"] = "ctrl_f",
  ["\007"] = "ctrl_g",
  ["\008"] = "ctrl_h", -- bs
  ["\009"] = "ctrl_i", -- ht
  ["\010"] = "ctrl_j", -- lf
  ["\011"] = "ctrl_k",
  ["\012"] = "ctrl_l", -- ff
  ["\013"] = "ctrl_m", -- cr
  ["\014"] = "ctrl_n",
  ["\015"] = "ctrl_o",
  ["\016"] = "ctrl_p",
  ["\017"] = "ctrl_q",
  ["\018"] = "ctrl_r",
  ["\019"] = "ctrl_s",
  ["\020"] = "ctrl_t",
  ["\021"] = "ctrl_u",
  ["\022"] = "ctrl_v",
  ["\023"] = "ctrl_w",
  ["\024"] = "ctrl_x",
  ["\025"] = "ctrl_y",
  ["\026"] = "ctrl_z",
  ["\027"] = "ctrl_[",  -- esc
  ["\028"] = "ctrl_\\", -- fs
  ["\029"] = "ctrl_]",  -- gs
  ["\030"] = "ctrl_^",  -- rs
  ["\031"] = "ctrl__",  -- us
  ["\127"] = "ctrl_?",  -- del
}


--- The default list of key-mapping from raw-input to key names.
-- @table default_key_map
M.default_key_map = {}
M.default_key_map = { -- to work around some LDoc bug :(
  -- ANSI escape sequences (base keys)
  ["\027[A"] = "up",        ["\027OA"] = "up",
  ["\027[B"] = "down",      ["\027OB"] = "down",
  ["\027[C"] = "right",     ["\027OC"] = "right",
  ["\027[D"] = "left",      ["\027OD"] = "left",
  ["\027[H"] = "home",      ["\027OH"] = "home",
  ["\027[F"] = "end",       ["\027OF"] = "end",
  ["\027[2~"] = "insert",
  ["\027[3~"] = "delete",
  ["\027[5~"] = "pageup",
  ["\027[6~"] = "pagedown",

  -- Ctrl + Arrow/Home/End
  ["\027[1;5A"] = "ctrl_up",
  ["\027[1;5B"] = "ctrl_down",
  ["\027[1;5C"] = "ctrl_right",
  ["\027[1;5D"] = "ctrl_left",
  ["\027[1;5H"] = "ctrl_home",
  ["\027[1;5F"] = "ctrl_end",

  -- Shift + Arrow/Home/End
  ["\027[1;2A"] = "shift_up",
  ["\027[1;2B"] = "shift_down",
  ["\027[1;2C"] = "shift_right",
  ["\027[1;2D"] = "shift_left",
  ["\027[1;2H"] = "shift_home",
  ["\027[1;2F"] = "shift_end",

  -- Alt + Arrow/Home/End
  ["\027[1;3A"] = "alt_up",
  ["\027[1;3B"] = "alt_down",
  ["\027[1;3C"] = "alt_right",
  ["\027[1;3D"] = "alt_left",
  ["\027[1;3H"] = "alt_home",
  ["\027[1;3F"] = "alt_end",

  -- Function keys
  ["\027OP"]  = "f1",     ["\027[11~"] = "f1",
  ["\027OQ"]  = "f2",     ["\027[12~"] = "f2",
  ["\027OR"]  = "f3",     ["\027[13~"] = "f3",
  ["\027OS"]  = "f4",     ["\027[14~"] = "f4",
  ["\027[15~"] = "f5",
  ["\027[17~"] = "f6",
  ["\027[18~"] = "f7",
  ["\027[19~"] = "f8",
  ["\027[20~"] = "f9",
  ["\027[21~"] = "f10",
  ["\027[23~"] = "f11",
  ["\027[24~"] = "f12",
  -- Extended function keys (F13–F20)
  ["\027[25~"] = "f13",
  ["\027[26~"] = "f14",
  ["\027[28~"] = "f15",
  ["\027[29~"] = "f16",
  ["\027[31~"] = "f17",
  ["\027[32~"] = "f18",
  ["\027[33~"] = "f19",
  ["\027[34~"] = "f20",

  -- Special sequences
  ["\027[Z"]   = "shift_tab",
  ["\027[200~"] = "bracketed_paste_start",
  ["\027[201~"] = "bracketed_paste_end",

  -- alt-combinations
  ["\027!"] = "alt_!",
  ["\027\""] = "alt_\"",
  ["\027#"] = "alt_#",
  ["\027$"] = "alt_$",
  ["\027%"] = "alt_%",
  ["\027&"] = "alt_&",
  ["\027'"] = "alt_'",
  ["\027("] = "alt_(",
  ["\027)"] = "alt_)",
  ["\027*"] = "alt_*",
  ["\027+"] = "alt_+",
  ["\027,"] = "alt_,",
  ["\027-"] = "alt_-",
  ["\027."] = "alt_.",
  ["\027/"] = "alt_/",
  ["\0270"] = "alt_0",
  ["\0271"] = "alt_1",
  ["\0272"] = "alt_2",
  ["\0273"] = "alt_3",
  ["\0274"] = "alt_4",
  ["\0275"] = "alt_5",
  ["\0276"] = "alt_6",
  ["\0277"] = "alt_7",
  ["\0278"] = "alt_8",
  ["\0279"] = "alt_9",
  ["\027:"] = "alt_:",
  ["\027;"] = "alt_;",
  ["\027<"] = "alt_<",
  ["\027="] = "alt_=",
  ["\027>"] = "alt_>",
  ["\027?"] = "alt_?",
  ["\027@"] = "alt_@",
  ["\027A"] = "alt_A",
  ["\027B"] = "alt_B",
  ["\027C"] = "alt_C",
  ["\027D"] = "alt_D",
  ["\027E"] = "alt_E",
  ["\027F"] = "alt_F",
  ["\027G"] = "alt_G",
  ["\027H"] = "alt_H",
  ["\027I"] = "alt_I",
  ["\027J"] = "alt_J",
  ["\027K"] = "alt_K",
  ["\027L"] = "alt_L",
  ["\027M"] = "alt_M",
  ["\027N"] = "alt_N",
  ["\027O"] = "alt_O",
  ["\027P"] = "alt_P",
  ["\027Q"] = "alt_Q",
  ["\027R"] = "alt_R",
  ["\027S"] = "alt_S",
  ["\027T"] = "alt_T",
  ["\027U"] = "alt_U",
  ["\027V"] = "alt_V",
  ["\027W"] = "alt_W",
  ["\027X"] = "alt_X",
  ["\027Y"] = "alt_Y",
  ["\027Z"] = "alt_Z",
  ["\027["] = "alt_[",
  ["\027\\"] = "alt_\\",
  ["\027]"] = "alt_]",
  ["\027^"] = "alt_^",
  ["\027_"] = "alt__",
  ["\027`"] = "alt_`",
  ["\027a"] = "alt_a",
  ["\027b"] = "alt_b",
  ["\027c"] = "alt_c",
  ["\027d"] = "alt_d",
  ["\027e"] = "alt_e",
  ["\027f"] = "alt_f",
  ["\027g"] = "alt_g",
  ["\027h"] = "alt_h",
  ["\027i"] = "alt_i",
  ["\027j"] = "alt_j",
  ["\027k"] = "alt_k",
  ["\027l"] = "alt_l",
  ["\027m"] = "alt_m",
  ["\027n"] = "alt_n",
  ["\027o"] = "alt_o",
  ["\027p"] = "alt_p",
  ["\027q"] = "alt_q",
  ["\027r"] = "alt_r",
  ["\027s"] = "alt_s",
  ["\027t"] = "alt_t",
  ["\027u"] = "alt_u",
  ["\027v"] = "alt_v",
  ["\027w"] = "alt_w",
  ["\027x"] = "alt_x",
  ["\027y"] = "alt_y",
  ["\027z"] = "alt_z",
  ["\027{"] = "alt_{",
  ["\027|"] = "alt_|",
  ["\027}"] = "alt_}",
  ["\027~"] = "alt_~",
}
-- Add control characters to the default key map
for raw, name in pairs(M.control_characters) do
  M.default_key_map[raw] = name
end



--- Returns a new key-map to map incoming raw key-strokes to a key-name.
-- Generates a new key-map, containing the `default_key_map`, and the provided overrides.
-- @tparam[opt] table overrides a table with key-value pairs to override the default key map.
-- The key should be the raw-key (character or sequence) as returned by `readansi`, the value
-- should be the name of the key.
-- @treturn table new key_map
-- @usage
-- -- use overrides to re-map vim-oriented keys to arrow-keys
-- local keys = terminal.input.keymap.default_keys
-- local vi_keymap = terminal.input.keymap.get_keymap({
--   ["j"] = keys.down,   -- use lookup table, not magic strings
--   ["k"] = keys.up,     -- use lookup table, not magic strings
-- })
--
-- local keystroke, keytype = terminal.input.readansi(math.huge)
-- local keyname = vi_keymap[keystroke]
--
-- if keyname == nil then
--   print("this key is unnamed: " .. keystroke:gsub("\027", "\\027"))
-- elseif keyname == keys.up then      -- matches "k" and arrow-up press
--   print("Up key pressed")
-- elseif keyname == keys.down then    -- matches "j" and arrow-down press
--   print("Down key pressed")
-- else
--   ...
-- end
function M.get_keymap(overrides)
  local key_map = {}

  for k, v in pairs(M.default_key_map) do
    key_map[k] = v
  end

  for k, v in pairs(overrides or {}) do
    key_map[k] = v
  end

  return key_map
end



do
  -- Aliases for user-friendly or alternate names
  --   key: the alias to add
  --   value: the name of the existing key to map to
  local default_key_aliases = {
    -- Human-readable aliases
    ["backspace"] = "ctrl_h",
    ["tab"] = "ctrl_i",
    ["enter"] = sys.windows and "ctrl_m" or "ctrl_j",
    ["return"] = sys.windows and "ctrl_m" or "ctrl_j",
    ["newline"] = "ctrl_j",
    ["escape"] = "ctrl_[",

    -- Control key aliases
    ["null"] = "ctrl_@",
    ["soh"] = "ctrl_a",
    ["stx"] = "ctrl_b",
    ["etx"] = "ctrl_c",
    ["eot"] = "ctrl_d",
    ["enq"] = "ctrl_e",
    ["ack"] = "ctrl_f",
    ["bel"] = "ctrl_g",
    ["bs"]  = "ctrl_h",
    ["ht"]  = "ctrl_i",
    ["lf"]  = "ctrl_j",
    ["vt"]  = "ctrl_k",
    ["ff"]  = "ctrl_l",
    ["cr"]  = "ctrl_m",
    ["so"]  = "ctrl_n",
    ["si"]  = "ctrl_o",
    ["dle"] = "ctrl_p",
    ["dc1"] = "ctrl_q",
    ["dc2"] = "ctrl_r",
    ["dc3"] = "ctrl_s",
    ["dc4"] = "ctrl_t",
    ["nak"] = "ctrl_u",
    ["syn"] = "ctrl_v",
    ["etb"] = "ctrl_w",
    ["can"] = "ctrl_x",
    ["em"]  = "ctrl_y",
    ["sub"] = "ctrl_z",
    ["esc"] = "ctrl_[",
    ["fs"]  = "ctrl_\\",
    ["gs"]  = "ctrl_]",
    ["rs"]  = "ctrl_^",
    ["us"]  = "ctrl__",
    ["del"]  = "ctrl_?",
  }


  local keys_mt = {
    __index = function(self, k)
      error("Unknown key-name: " .. tostring(k), 2)
    end,
  }


  --- Returns a constant lookup table with key-names.
  -- It will contain everything from the `keymap` table, the default key-aliases, and the provided
  -- aliasses.
  -- Looking up an unknown name will throw an error. Use this instead of magic-strings
  -- when checking for specific keys.
  -- @tparam[opt=default-key-map] table keymap, either `default_key_map`, or the result from `get_keymap`.
  -- @tparam[opt] table aliasses a table with key-value pairs to override the default key map.
  -- The key is the alias, the value is the official name of the key.
  -- @treturn table constant table where the aliases/keys map to the official key names.
  -- @usage
  -- local keys = terminal.input.keymap.default_keys
  -- local rawkey = terminal.input.readansi(math.huge)
  -- local keyname = terminal.input.keymap.default_key_map[key]
  --
  -- if     keyname == "up" then     -- will work
  -- elseif keyname == "upx" then    -- will not work, but will silently be ignored
  -- elseif keyname == keys.up then  -- will work
  -- elseif keyname == keys.upx then -- will throw an error, due to typo
  -- end
  function M.get_keys(keymap, aliasses)
    keymap = keymap or M.default_key_map
    local constant_map = {}

    for _, v in pairs(keymap) do
      constant_map[v] = v
    end

    -- add the default key-aliases
    for k, v in pairs(default_key_aliases) do
      constant_map[k] = constant_map[v]
    end

    -- add the aliases
    for k, v in pairs(aliasses or {}) do
      constant_map[k] = constant_map[v]
    end

    setmetatable(constant_map, keys_mt)

    return constant_map
  end
end



--- The default lookup table with key-names.
-- @table default_keys
M.default_keys = M.get_keys(M.default_key_map)



--- Checks if a raw-key is printable.
-- A printable key is a key that is not an ANSI escape sequence and not a control character (bytes
-- 0-31 and 127).
--
-- **Note**: Tab, Cr, and Lf, which are control characters, are considered non-printable by this function.
-- @tparam string keystroke the raw key-stroke as returned by `readansi`.
-- @treturn boolean `true` if the key is printable, `false` otherwise.
function M.is_printable(keystroke)
  if keystroke:sub(1,1) == "\027" then
    return false -- is ANSI sequence, or plain Esc
  end

  -- Check if the keystroke is a control character
  return not M.control_characters[keystroke]
end



return M

