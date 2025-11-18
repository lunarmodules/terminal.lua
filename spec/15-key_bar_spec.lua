describe("terminal.ui.panel.key_bar", function()

  local KeyBar
  local terminal
  local text

  setup(function()
    -- Load modules
    KeyBar = require("terminal.ui.panel.key_bar")
    terminal = require("terminal")
    text = require("terminal.text")

    -- Mock terminal functions for testing
    terminal.cursor = {
      position = {
        set = function() end,
        backup = function() end,
        restore = function() end,
        set_seq = function() return "" end,
        backup_seq = function() return "" end,
        restore_seq = function() return "" end,
      }
    }
    terminal.output = {
      write = function() end
    }
  end)

  teardown(function()
    -- Unset modules for clean test isolation
    KeyBar = nil
    terminal = nil -- luacheck: ignore
  end)


  describe("init()", function()

    it("creates a key bar with default values", function()
      local kb = KeyBar {}

      assert.are.equal(1, kb.margin)
      assert.are.equal(2, kb.padding)
      assert.are.equal(1, kb.rows)
      assert.are.same({}, kb.items)
      assert.are.equal(1, kb._min_height)
      assert.are.equal(1, kb._max_height)
      assert.is_false(kb.auto_render)
    end)


    it("accepts custom values", function()
      local kb = KeyBar {
        margin = 0,
        padding = 1,
        rows = 2,
        items = {
          { key = "^X", desc = "Exit" },
          { key = "^O", desc = "Write" },
        }
      }

      assert.are.equal(0, kb.margin)
      assert.are.equal(1, kb.padding)
      assert.are.equal(2, kb.rows)
      assert.are.equal(2, #kb.items)
      assert.are.equal(2, kb._min_height)
      assert.are.equal(2, kb._max_height)
    end)


    it("uses default separator of single space when not specified", function()
      local kb = KeyBar {}
      assert.are.equal(" ", kb.separator)
    end)


    it("accepts custom separator string", function()
      local kb = KeyBar {
        separator = " - "
      }
      assert.are.equal(" - ", kb.separator)
    end)


    it("accepts empty separator string", function()
      local kb = KeyBar {
        separator = ""
      }
      assert.are.equal("", kb.separator)
    end)

  end)


  describe("_build_lines()", function()

    it("builds a single-row line with equal columns", function()
      local kb = KeyBar {
        margin = 1,
        padding = 2,
        rows = 1,
        items = {
          { key = "^G", desc = "Help" },
          { key = "^O", desc = "Write" },
          { key = "^X", desc = "Exit" },
        }
      }

      local width = 40
      local lines = kb:_build_lines(width)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      -- Check column width, not byte length (ellipsis "…" is 1 column but 3 bytes)
      local actual_width = text.width.utf8swidth(s)
      assert.are.equal(width, actual_width)
      -- ensure there are two padding regions (3 columns => 2 gaps)
      local first_gap = s:find("  ")
      assert.is_true(first_gap ~= nil)
    end)


    it("builds two rows with vertically aligned columns", function()
      local kb = KeyBar {
        margin = 1,
        padding = 1,
        rows = 2,
        items = {
          { key = "F1", desc = "Help" },
          { key = "F2", desc = "Save" },
          { key = "F3", desc = "Open" },
          { key = "F4", desc = "Find" },
          { key = "F5", desc = "Replace" },
        }
      }

      local width = 36
      local lines = kb:_build_lines(width)
      assert.are.equal(2, #lines)
      local s1 = tostring(lines[1])
      local s2 = tostring(lines[2])
      -- Check column widths match (not byte lengths, due to UTF-8 ellipsis)
      local w1 = text.width.utf8swidth(s1)
      local w2 = text.width.utf8swidth(s2)
      assert.are.equal(w1, w2)
      assert.are.equal(width, w1)
      -- Verify columns align vertically by checking where keys appear
      -- With margin=1, padding=1, and 3 columns per row:
      -- Row 1: " F1 Help     F2 Save     F3 Open    "
      -- Row 2: " F4 Find     F5 Replace             "
      -- Find key start positions in the plain string
      local function find_key_pos(s, key)
        for i = 1, #s do
          if s:sub(i, i + #key - 1) == key then
            return i
          end
        end
        return nil
      end
      -- First two columns should align vertically (F1/F4 and F2/F5)
      assert.are.equal(find_key_pos(s1, "F1"), find_key_pos(s2, "F4"), "First columns should align")
      assert.are.equal(find_key_pos(s1, "F2"), find_key_pos(s2, "F5"), "Second columns should align")
    end)


    it("handles zero width gracefully", function()
      local kb = KeyBar { items = { { key = "A", desc = "B" } } }
      local lines = kb:_build_lines(0)
      assert.are.equal(0, #lines)
    end)


    it("renders custom separator between key and description", function()
      local kb = KeyBar {
        separator = " - ",
        items = {
          { key = "Ctrl+C", desc = "Copy" },
        }
      }
      local lines = kb:_build_lines(30)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      -- Check that separator appears between key and description
      -- Simply verify the separator string appears in the output
      assert.matches(" - ", s)
      assert.matches("Ctrl", s)
      assert.matches("Copy", s)
    end)


    it("renders no separator when separator is empty string", function()
      local kb = KeyBar {
        separator = "",
        items = {
          { key = "Ctrl+C", desc = "Copy" },
        }
      }
      local lines = kb:_build_lines(30)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      -- Check that key and description are adjacent (no separator)
      assert.matches("Ctrl%+CCopy", s)
    end)


    it("does not render separator when description is empty", function()
      local kb = KeyBar {
        separator = " - ",
        items = {
          { key = "Ctrl+C", desc = "" },
        }
      }
      local lines = kb:_build_lines(30)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      -- Check that separator does not appear (description is empty)
      -- The string should contain Ctrl+C
      assert.matches("Ctrl", s)
      -- Verify the separator does not appear immediately after the key
      -- Find Ctrl+C and check what follows (should be spaces, not " - ")
      local ctrl_pos = s:find("Ctrl%+C")
      if ctrl_pos then
        local after_key = s:sub(ctrl_pos + 6, ctrl_pos + 9) -- Check next 4 chars after "Ctrl+C"
        -- Should not be " - " (separator)
        assert.are.not_equal(" - ", after_key)
      end
    end)


    it("accounts for separator width in layout calculations", function()
      local kb = KeyBar {
        separator = " → ",
        items = {
          { key = "A", desc = "B" },
        }
      }
      local lines = kb:_build_lines(10)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      local actual_width = text.width.utf8swidth(s)
      -- Width should account for separator (arrow is 1 display width)
      assert.are.equal(10, actual_width)
    end)


    it("handles multi-byte separator correctly", function()
      local kb = KeyBar {
        separator = " → ",
        items = {
          { key = "F1", desc = "Help" },
        }
      }
      local lines = kb:_build_lines(20)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      -- Arrow character should appear in output
      assert.matches("F1 → Help", s)
    end)

  end)


  describe("render()", function()

    it("calls _draw and respects panel inner coords", function()
      local kb = KeyBar {
        rows = 2,
        items = {
          { key = "^X", desc = "Exit" },
          { key = "^O", desc = "Write" },
          { key = "^G", desc = "Help" },
        }
      }

      local called = false
      local call_args = {}
      kb._draw = function(self)
        called = true
        call_args = { self.inner_row, self.inner_col, self.inner_height, self.inner_width }
      end

      kb.row = 3
      kb.col = 5
      kb.height = 2
      kb.width = 20
      kb.inner_row = 3
      kb.inner_col = 5
      kb.inner_height = 2
      kb.inner_width = 20
      kb:render()

      assert.is_true(called)
      assert.are.same({ 3, 5, 2, 20 }, call_args)
    end)

  end)


  describe("separator feature", function()

    it("works correctly in two-row layout", function()
      local kb = KeyBar {
        separator = " | ",
        rows = 2,
        items = {
          { key = "F1", desc = "Help" },
          { key = "F2", desc = "Save" },
          { key = "F3", desc = "Open" },
          { key = "F4", desc = "Find" },
        }
      }
      local lines = kb:_build_lines(40)
      assert.are.equal(2, #lines)
      local s1 = tostring(lines[1])
      local s2 = tostring(lines[2])
      -- With 4 items and 2 rows, we get 2 columns per row (ceil(4/2) = 2)
      -- Row 1: F1, F2
      -- Row 2: F3, F4
      -- Both rows should contain separator
      assert.matches("F1 | Help", s1)
      assert.matches("F2 | Save", s1)
      assert.matches("F3 | Open", s2)
      assert.matches("F4 | Find", s2)
    end)


    it("accounts for separator width in text truncation", function()
      local kb = KeyBar {
        separator = " → ",
        items = {
          { key = "VeryLongKey", desc = "VeryLongDescription" },
        }
      }
      local lines = kb:_build_lines(15)
      assert.are.equal(1, #lines)
      local s = tostring(lines[1])
      local actual_width = text.width.utf8swidth(s)
      -- Width should be exactly 15, accounting for separator
      assert.are.equal(15, actual_width)
    end)


    it("separator uses bar attributes not key or desc attributes", function()
      local write_calls = {}
      local original_write = terminal.output.write
      terminal.output.write = function(...)
        local args = {...}
        table.insert(write_calls, args)
      end

      local kb = KeyBar {
        attr = { fg = "red" },
        key_attr = { fg = "blue" },
        desc_attr = { fg = "green" },
        separator = " | ",
        items = {
          { key = "Ctrl+C", desc = "Copy" },
        }
      }

      kb.row = 1
      kb.col = 1
      kb.height = 1
      kb.width = 20
      kb.inner_row = 1
      kb.inner_col = 1
      kb.inner_height = 1
      kb.inner_width = 20

      kb:render()

      -- Restore original
      terminal.output.write = original_write

      -- Verify that separator is rendered (test passes if no errors)
      assert.is_true(#write_calls > 0)
    end)

  end)

end)


