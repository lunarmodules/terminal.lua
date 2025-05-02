local sys = require("system")
local t = require("terminal")
local w = t.text.width
local p = t.cursor.position
local ou = t.output
local utf8 = require("utf8")

local function inverse_table(t_)
    local i = {}
    for k, v in pairs(t_) do
        i[v] = k
    end
    return i
end

-- Mapping of key-sequences to key-names
local key_names = {
    ["\27[C"] = "right",
    ["\27[D"] = "left",
    ["\127"] = "backspace",
    ["\27[3~"] = "delete",
    ["\27[H"] = "home",
    ["\27[F"] = "end",
    ["\27"] = "escape",
    ["\9"] = "tab",
    ["\27[Z"] = "shift-tab",
    [sys.windows and "\13" or "\10"] = "enter",
}
-- Mapping of key-names to key-sequences
local key_sequences = inverse_table(key_names)
-- The keys that will cause the readline to exit:
-- enter, escape, tab, shift-tab
local exit_keys = inverse_table { key_sequences.enter, "\27", "\t", "\27[Z" }

-- bell character
local function bell()
    ou.write("\7")
    ou.flush()
end

local utf8_value_mt
local utf8parse = {}
do
    utf8_value_mt = {
        __index = utf8parse,
        __tostring = function(self)
            local head = self.head
            local res = {}
            while head do
                res[#res + 1] = head.value or ""
                head = head.next
            end
            return table.concat(res)
        end
    }
    -- Parses a UTF8 string into list of individual characters.
    -- @tparam string s the UTF8 string to parse
    -- @treturn table the list of characters
    function utf8parse.new(s)
        local self = setmetatable({
            icursor = {},          -- tracking the cursor internally (inside the table)
            ocursor = 1,           -- tracking the cursor externally (as displayed)
            ilen = 0,              -- tracking the length internally (# of utf8 characters)
            olen = 0,              -- tracking the length externally (# of displayed columns)
            head = {}              -- start of the list
        }, utf8_value_mt)
        self.tail = self.icursor -- prepare linked list
        self.tail.prev = self.head
        self.head.next = self.tail
        if s and #s ~= 0 then
            for _, c in utf8.codes(s) do
                self:add(utf8.char(c))
            end
        end
        return self
    end

    function utf8parse:add(c) -- add to string at index
        if c == nil then return end
        local node = { value = c, next = self.icursor, prev = self.icursor.prev }
        self.icursor.prev.next = node
        self.icursor.prev = node
        self.ilen = self.ilen + 1
        self.olen = self.olen + w.utf8cwidth(c)
        self.ocursor = self.ocursor + w.utf8cwidth(c)
    end

    function utf8parse:backspace() -- backspace at cursor
        if self.icursor.prev == self.head then return end
        local prev = self.icursor.prev.prev or self.head
        local next = self.icursor
        local c = self.icursor.prev.value
        prev.next = next
        next.prev = prev
        self.ilen = self.ilen - 1
        self.olen = self.olen - w.utf8cwidth(c)
        self.ocursor = self.ocursor - w.utf8cwidth(c)
    end

    function utf8parse:left()
        if self.icursor.prev == self.head then return end
        self.icursor = self.icursor.prev
        self.ocursor = self.ocursor - (self.icursor.value and w.utf8cwidth(self.icursor.value) or 1)
    end

    function utf8parse:right()
        if self.icursor == self.tail then return end
        self.ocursor = self.ocursor + (self.icursor.value and w.utf8cwidth(self.icursor.value) or 1)
        self.icursor = self.icursor.next
    end

    function utf8parse:delete()
        if self.icursor == self.tail then return end
        self:right()
        self:backspace()
    end
end


local readline = {}
local readline_mt = { __index = readline }

function readline:new()
    local value = utf8parse.new(self.value)
    local prompt = utf8parse.new(self.prompt)
    local fsleep = self.fsleep or sys.sleep
    local _, cols = t.size()
    local max_length = math.min(self.max_length, cols - prompt.olen - (value.olen - value.ilen))
    -- local pos = math.floor(opts.position or (#value + 1))

    self = setmetatable({
        value = value,           -- the default value
        max_length = max_length, -- the maximum length of the input
        prompt = prompt,         -- the prompt to display
        -- pos = pos,             -- the current cursor position
        drawn_before = false,    -- if the prompt has been drawn
        fsleep = fsleep,         -- the sleep function to use
    }, readline_mt)

    return self
end

function readline:draw(redraw)
    if redraw or not self.prompt_ready then
        -- we are at start of prompt
        self.prompt_ready = true
        p.column(1)
        ou.write(tostring(self.prompt))
    else
        -- we are at current cursor position, move to start of prompt
        p.column(self.prompt.olen + 1)
    end
    -- write prompt & value
    local value = tostring(self.value)
    ou.write(value)
    -- clear remainder of input size
    ou.write(string.rep(" ", self.max_length - self.value.olen))
    -- move to cursor position
    p.column(self.prompt.olen + self.value.ocursor)
    ou.flush()
end

function readline:handle_key(key, keytype)
    -- registered exit key
    if exit_keys[key] then
        return "exit_key"
    end

    -- registered editting key
    local handler = self.value[key_names[key]]
    if handler then
        handler(self.value)
        self:draw()
        return "ok"
    end
    -- unregistered ansi sequence
    if keytype == "ansi" then
        -- print("unhandled ansi: ", key:sub(2,-1), string.byte(key, 1, -1))
        bell()
        return "ok"
    end
    -- control character
    if key < " " then
        bell()
        return "ok"
    end
    -- maximum length reached
    if self.value.ilen >= self.max_length then
        bell()
        return "ok"
    end
    -- add the new received key to the string
    self.value:add(key)
    self:draw()
    return "ok"
end

--- Processes key input using an event-driven approach.
-- This function listens for key events and processes them.
-- If an exit key is pressed, it yields the input value and the exit key.
-- @event key Triggered when a key is pressed.
-- @tparam string key The key that was pressed.
-- @tparam string keytype The type of the key (e.g., "ansi", "control").
function readline:readkey_co()
    while true do
        local key, keytype = t.input.readansi(0.1, self.fsleep) -- blocking sleep
        if key then
            local status = self:handle_key(key, keytype)
            if status == "exit_key" then   -- exit key pressed?
                coroutine.yield(tostring(self.value), key)
            elseif status ~= "ok" then
                error(status)
            end
        end
    end
end

--- Starts the readline input loop.
-- This function initializes the input loop for the readline instance.
-- It uses a coroutine to process key input until an exit key is pressed.
-- @tparam boolean redraw Whether to redraw the prompt initially.
-- @treturn string The final input value entered by the user.
-- @treturn string The exit key that terminated the input loop.
function readline:run(redraw)
    self:draw(redraw)

    local co = coroutine.create(function() self:readkey_co() end)
    while true do
        local status, result, exitkey = coroutine.resume(co)
        if not status then
            error("Coroutine error: " .. tostring(result))
        end
        if result and exitkey then
            return result, exitkey
        end
    end
end

t.initwrap({}, function(opts)
    local rl = readline.new(opts)
    local result, exitkey = rl:run()

    ou.print() -- move to new line (we're still on the 'press any key' line)
    ou.print("Result (string): '" .. result .. "'")
    ou.print("Result (bytes):", (result or ""):byte(1, -1))
    ou.print("Exit-Key (bytes):", exitkey:byte(1, -1))

    return true
end, {
    prompt = "Enter something: ",
    value = "Hello, 你-好 World 🚀!",
    max_length = 62,
    -- position = 2,
    fsleep = sys.sleep,
})
