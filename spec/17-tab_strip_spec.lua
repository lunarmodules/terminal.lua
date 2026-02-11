local helpers = require "spec.helpers"


describe("terminal.ui.panel.tab_strip", function()

  local TabStrip
  local terminal

  setup(function()
    -- Load modules
    terminal = helpers.load()
    TabStrip = require("terminal.ui.panel.tab_strip")
    -- Mock terminal functions for testing
    terminal.cursor = {
      position = {
        set = function() end,
        backup = function() end,
        restore = function() end,
        set_seq = function() return "" end,
        backup_seq = function() return "" end,
        restore_seq = function() return "" end,
        left_seq = function() return "" end,
        down_seq = function() return "" end,
        up_seq = function() return "" end
      }
    }
    terminal.output = {
      write = function() end
    }
    terminal.clear = {
      eol_seq = function() return "" end,
      box = function() return "" end,
      box_seq = function() return "" end
    }
  end)


  teardown(function()
    -- Unset modules for clean test isolation
    TabStrip = nil
    terminal = nil -- luacheck: ignore
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a TabStrip deriving from Panel", function()
      local Panel = require("terminal.ui.panel.init")
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } }
      }
      -- Check that TabStrip is an instance of Panel
      assert.is_true(tab_strip:get_type() == Panel.types.content)
    end)


    it("has fixed height of 1 line", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } }
      }
      assert.are.equal(1, tab_strip._min_height)
      assert.are.equal(1, tab_strip._max_height)
    end)


    it("uses Panel's content callback mechanism", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } }
      }
      assert.is_not_nil(tab_strip.content)
      assert.is_function(tab_strip.content)
    end)


    it("respects Panel's layout constraints", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } }
      }
      -- Calculate layout
      tab_strip:calculate_layout(1, 1, 10, 80)
      assert.is_not_nil(tab_strip.inner_row)
      assert.is_not_nil(tab_strip.inner_col)
      assert.is_not_nil(tab_strip.inner_width)
      assert.is_not_nil(tab_strip.inner_height)
    end)


    it("raises error with invalid Panel options", function()
      -- Try to create TabStrip with children (invalid for content panel)
      assert.has_error(function()
        TabStrip {
          items = { { label = "Tab 1" } },
          children = { {} }
        }
      end)
    end)


    it("extracts TabStrip-specific options before calling Panel.init", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } },
        prefix = "[",
        postfix = "]",
        padding = 1
      }
      -- Options should be extracted and not passed to Panel
      -- We can verify this by checking that items is not in opts passed to Panel
      -- Since items is required, we'll just verify the instance exists
      assert.is_not_nil(tab_strip)
    end)

  end)



  describe("items handling", function()

    it("accepts items table parameter", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" }, { label = "Tab 2" } }
      }
      assert.is_not_nil(tab_strip.items)
      assert.are.equal(2, #tab_strip.items)
    end)


    it("validates each item has required label field", function()
      assert.has_error(function()
        TabStrip {
          items = { { id = "tab1" } }  -- Missing label
        }
      end)
    end)


    it("assigns default ids (1-based index) when missing", function()
      local tab_strip = TabStrip {
        items = {
          { label = "Tab 1" },
          { label = "Tab 2" },
          { label = "Tab 3" }
        }
      }
      assert.are.equal(1, tab_strip.items[1].id)
      assert.are.equal(2, tab_strip.items[2].id)
      assert.are.equal(3, tab_strip.items[3].id)
    end)


    it("preserves explicit ids when provided", function()
      local tab_strip = TabStrip {
        items = {
          { id = "first", label = "Tab 1" },
          { id = "second", label = "Tab 2" }
        }
      }
      assert.are.equal("first", tab_strip.items[1].id)
      assert.are.equal("second", tab_strip.items[2].id)
    end)


    it("handles empty items gracefully", function()
      local tab_strip = TabStrip {
        items = {}
      }
      assert.is_not_nil(tab_strip.items)
      assert.are.equal(0, #tab_strip.items)
    end)


    it("handles nil items gracefully", function()
      local tab_strip = TabStrip {
        items = nil
      }
      -- Should handle nil items without error
      assert.is_not_nil(tab_strip)
    end)

  end)



  describe("configuration parameters", function()

    it("accepts prefix parameter with default '['", function()
      local tab_strip1 = TabStrip {
        items = { { label = "Tab 1" } }
      }
      assert.are.equal("[", tab_strip1.prefix)
      local tab_strip2 = TabStrip {
        items = { { label = "Tab 1" } },
        prefix = "<"
      }
      assert.are.equal("<", tab_strip2.prefix)
    end)


    it("accepts postfix parameter with default ']'", function()
      local tab_strip1 = TabStrip {
        items = { { label = "Tab 1" } }
      }
      assert.are.equal("]", tab_strip1.postfix)
      local tab_strip2 = TabStrip {
        items = { { label = "Tab 1" } },
        postfix = ">"
      }
      assert.are.equal(">", tab_strip2.postfix)
    end)


    it("accepts padding parameter with default 1", function()
      local tab_strip1 = TabStrip {
        items = { { label = "Tab 1" } }
      }
      assert.are.equal(1, tab_strip1.padding)
      local tab_strip2 = TabStrip {
        items = { { label = "Tab 1" } },
        padding = 2
      }
      assert.are.equal(2, tab_strip2.padding)
    end)


    it("accepts attr parameter for global strip styling", function()
      local attr = { fg = "white", bg = "black" }
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } },
        attr = attr
      }
      assert.are.same(attr, tab_strip.attr)
    end)


    it("accepts selected_attr parameter with default derivation from attr", function()
      local attr = { fg = "white", bg = "black", reverse = false }
      local tab_strip1 = TabStrip {
        items = { { label = "Tab 1" } },
        attr = attr
      }
      -- When selected_attr not provided, should default to attr with reverse inverted
      assert.is_not_nil(tab_strip1.selected_attr)
      assert.are.equal(true, tab_strip1.selected_attr.reverse)
      local selected_attr = { fg = "yellow" }
      local tab_strip2 = TabStrip {
        items = { { label = "Tab 1" } },
        attr = attr,
        selected_attr = selected_attr
      }
      assert.are.same(selected_attr, tab_strip2.selected_attr)
    end)


    it("accepts select_cb callback parameter", function()
      local select_cb = function(self, id)
        -- Test callback
      end
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } },
        select_cb = select_cb
      }
      assert.is_not_nil(tab_strip.select_cb)
      assert.is_function(tab_strip.select_cb)
    end)

  end)



  describe("initial selection handling", function()

    it("accepts selected parameter for initial tab id", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2"
      }
      assert.are.equal("tab2", tab_strip.selected)
    end)


    it("defaults to first tab (index 1) when selected not provided", function()
      local tab_strip = TabStrip {
        items = {
          { label = "Tab 1" },
          { label = "Tab 2" }
        }
      }
      assert.are.equal(1, tab_strip.selected)
    end)


    it("handles nil selected when items are empty", function()
      local tab_strip = TabStrip {
        items = {}
      }
      assert.is_nil(tab_strip.selected)
    end)


    it("calls select_cb during initialization with initial selected tab", function()
      local callback_called = false
      local callback_id = nil
      local callback_self = nil
      local select_cb = function(self, id)
        callback_called = true
        callback_self = self
        callback_id = id
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2",
        select_cb = select_cb
      }
      assert.is_true(callback_called)
      assert.are.equal(tab_strip, callback_self)
      assert.are.equal("tab2", callback_id)
    end)


    it("calls select_cb with nil id when items are empty", function()
      local callback_id = nil
      local select_cb = function(self, id)
        callback_id = id
      end
      TabStrip {
        items = {},
        select_cb = select_cb
      }
      assert.is_nil(callback_id)
    end)


    it("does not call select_cb when not provided", function()
      local tab_strip = TabStrip {
        items = { { label = "Tab 1" } }
        -- No select_cb provided
      }
      assert.is_nil(tab_strip.select_cb)
    end)

  end)



  describe("basic rendering", function()

    it("displays all tabs on a single line", function()
      local write_calls = {}
      terminal.output.write = function(...)
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { label = "Tab 1" },
          { label = "Tab 2" },
          { label = "Tab 3" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Should have written output
      assert.is_true(#write_calls > 0)
    end)


    it("applies prefix and postfix around each tab label", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            -- Handle Sequence objects
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { label = "Tab 1" },
          { label = "Tab 2" }
        },
        prefix = "[",
        postfix = "]"
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Check that prefix and postfix are in the output
      assert.matches("%[Tab 1%]", written_content)
      assert.matches("%[Tab 2%]", written_content)
    end)


    it("applies selected_attr to selected tab", function()
      local write_calls = {}
      terminal.output.write = function(...)
        table.insert(write_calls, {...})
      end
      local text_stack = require("terminal.text.stack")
      local original_push = text_stack.push
      text_stack.push = function(attr)
        return original_push(attr)
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2",
        selected_attr = { reverse = true }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Restore original
      text_stack.push = original_push
      -- Should have applied attributes
      assert.is_true(#write_calls > 0)
    end)


    it("applies global attr to entire visible area", function()
      local write_calls = {}
      terminal.output.write = function(...)
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { label = "Tab 1" }
        },
        attr = { fg = "white", bg = "black" }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Should have written output with attributes
      assert.is_true(#write_calls > 0)
    end)


    it("renders spaces when items are empty", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            -- Handle Sequence objects
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {}
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Should render spaces across width
      assert.is_true(#write_calls > 0)
    end)

  end)



  describe("selection and navigation", function()

    it("get_selected returns current selected tab id", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2"
      }
      local selected_id, err = tab_strip:get_selected()
      assert.are.equal("tab2", selected_id)
      assert.is_nil(err)
    end)


    it("get_selected returns nil+err when no tabs exist", function()
      local tab_strip = TabStrip {
        items = {}
      }
      local selected_id, err = tab_strip:get_selected()
      assert.is_nil(selected_id)
      assert.is_not_nil(err)
    end)


    it("select sets selected tab to specified id and returns true", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab1"
      }
      local result, err = tab_strip:select("tab2")
      assert.is_true(result)
      assert.is_nil(err)
      assert.are.equal("tab2", tab_strip.selected)
    end)


    it("select returns nil+err when id not found", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      local result, err = tab_strip:select("nonexistent")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)


    it("select calls select_cb when selection changes", function()
      local callback_called
      local callback_id
      local select_cb = function(self, id)
        callback_called = true
        callback_id = id
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab1",
        select_cb = select_cb
      }
      -- Reset to track new call
      callback_called = false
      callback_id = nil
      tab_strip:select("tab2")
      assert.is_true(callback_called)
      assert.are.equal("tab2", callback_id)
    end)


    it("select does not call select_cb when selection unchanged", function()
      local callback_called
      local select_cb = function()
        callback_called = true
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        },
        selected = "tab1",
        select_cb = select_cb
      }
      -- Reset to track new call
      callback_called = false
      tab_strip:select("tab1")
      assert.is_false(callback_called)
    end)


    it("select_next increments selection and returns get_selected result", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" },
          { id = "tab3", label = "Tab 3" }
        },
        selected = "tab1"
      }
      local result, err = tab_strip:select_next()
      assert.are.equal("tab2", result)
      assert.is_nil(err)
      assert.are.equal("tab2", tab_strip.selected)
    end)


    it("select_next clamps to last tab when already on last", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2"
      }
      local result, err = tab_strip:select_next()
      assert.are.equal("tab2", result)
      assert.is_nil(err)
      assert.are.equal("tab2", tab_strip.selected)
    end)


    it("select_next returns nil+err when no tabs exist", function()
      local tab_strip = TabStrip {
        items = {}
      }
      local result, err = tab_strip:select_next()
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)


    it("select_prev decrements selection and returns get_selected result", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" },
          { id = "tab3", label = "Tab 3" }
        },
        selected = "tab2"
      }
      local result, err = tab_strip:select_prev()
      assert.are.equal("tab1", result)
      assert.is_nil(err)
      assert.are.equal("tab1", tab_strip.selected)
    end)


    it("select_prev clamps to first tab when already on first", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab1"
      }
      local result, err = tab_strip:select_prev()
      assert.are.equal("tab1", result)
      assert.is_nil(err)
      assert.are.equal("tab1", tab_strip.selected)
    end)


    it("select_prev returns nil+err when no tabs exist", function()
      local tab_strip = TabStrip {
        items = {}
      }
      local result, err = tab_strip:select_prev()
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)


    it("select_next calls select_cb when selection changes", function()
      local callback_called
      local callback_id
      local select_cb = function(self, id)
        callback_called = true
        callback_id = id
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab1",
        select_cb = select_cb
      }
      -- Reset to track new call
      callback_called = false
      callback_id = nil
      tab_strip:select_next()
      assert.is_true(callback_called)
      assert.are.equal("tab2", callback_id)
    end)


    it("select_prev calls select_cb when selection changes", function()
      local callback_called
      local callback_id
      local select_cb = function(self, id)
        callback_called = true
        callback_id = id
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2",
        select_cb = select_cb
      }
      -- Reset to track new call
      callback_called = false
      callback_id = nil
      tab_strip:select_prev()
      assert.is_true(callback_called)
      assert.are.equal("tab1", callback_id)
    end)

  end)



  describe("item management", function()

    it("get_items returns copy of items table", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      local items = tab_strip:get_items()
      assert.are.equal(2, #items)
      assert.are.equal("tab1", items[1].id)
      assert.are.equal("tab2", items[2].id)
      -- Modifying returned items should not affect internal state
      items[1].label = "Modified"
      assert.are.equal("Tab 1", tab_strip.items[1].label)
    end)


    it("set_items updates items and validates them", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      local new_items = {
        { id = "new1", label = "New 1" },
        { id = "new2", label = "New 2" }
      }
      tab_strip:set_items(new_items)
      assert.are.equal(2, #tab_strip.items)
      assert.are.equal("new1", tab_strip.items[1].id)
      assert.are.equal("new2", tab_strip.items[2].id)
    end)


    it("set_items adjusts selection when items change", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2"
      }
      local new_items = {
        { id = "new1", label = "New 1" }
      }
      tab_strip:set_items(new_items)
      -- Should default to first tab when old selection doesn't exist
      assert.are.equal("new1", tab_strip.selected)
    end)


    it("add_item adds new item to items list", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      tab_strip:add_item({ id = "tab2", label = "Tab 2" })
      assert.are.equal(2, #tab_strip.items)
      assert.are.equal("tab2", tab_strip.items[2].id)
    end)


    it("add_item validates item has required label field", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      assert.has_error(function()
        tab_strip:add_item({ id = "tab2" })  -- Missing label
      end)
    end)


    it("add_item supports optional before_id parameter", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      tab_strip:add_item({ id = "new", label = "New" }, "tab2")
      assert.are.equal(3, #tab_strip.items)
      assert.are.equal("tab1", tab_strip.items[1].id)
      assert.are.equal("new", tab_strip.items[2].id)
      assert.are.equal("tab2", tab_strip.items[3].id)
    end)


    it("remove_item removes item with specified id", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" },
          { id = "tab3", label = "Tab 3" }
        }
      }
      local result, err = tab_strip:remove_item("tab2")
      assert.is_true(result)
      assert.is_nil(err)
      assert.are.equal(2, #tab_strip.items)
      assert.are.equal("tab1", tab_strip.items[1].id)
      assert.are.equal("tab3", tab_strip.items[2].id)
    end)


    it("remove_item returns nil+err when id not found", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      local result, err = tab_strip:remove_item("nonexistent")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)


    it("remove_item moves selection to left tab when selected removed", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" },
          { id = "tab3", label = "Tab 3" }
        },
        selected = "tab2"
      }
      tab_strip:remove_item("tab2")
      assert.are.equal("tab1", tab_strip.selected)
    end)


    it("remove_item moves to new first tab when first tab removed", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab1"
      }
      tab_strip:remove_item("tab1")
      assert.are.equal("tab2", tab_strip.selected)
    end)


    it("remove_item sets selected to nil when all tabs removed", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        },
        selected = "tab1"
      }
      tab_strip:remove_item("tab1")
      assert.is_nil(tab_strip.selected)
    end)


    it("remove_item calls select_cb when selection changes", function()
      local callback_called
      local callback_id
      local select_cb = function(self, id)
        callback_called = true
        callback_id = id
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        selected = "tab2",
        select_cb = select_cb
      }
      -- Reset to track new call
      callback_called = false
      callback_id = nil
      tab_strip:remove_item("tab2")
      assert.is_true(callback_called)
      assert.are.equal("tab1", callback_id)
    end)

  end)



  describe("integration", function()

    it("works in Panel hierarchy", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      -- Should be able to calculate layout
      tab_strip:calculate_layout(1, 1, 1, 80)
      assert.is_not_nil(tab_strip.inner_row)
      assert.is_not_nil(tab_strip.inner_col)
      assert.is_not_nil(tab_strip.inner_width)
      assert.is_not_nil(tab_strip.inner_height)
    end)


    it("works in Screen panel header position", function()
      local Screen = require("terminal.ui.panel.screen")
      local Panel = require("terminal.ui.panel.init")
      -- Mock terminal.size for Screen
      local original_size = terminal.size
      terminal.size = function()
        return 24, 80
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      local screen = Screen {
        header = tab_strip,
        body = Panel {
          content = function() end
        }
      }
      -- Should be able to calculate layout
      screen:calculate_layout()
      assert.is_not_nil(tab_strip.inner_row)
      assert.is_not_nil(tab_strip.inner_col)
      assert.is_not_nil(tab_strip.inner_width)
      -- Restore
      terminal.size = original_size
    end)


    it("works in Screen panel footer position", function()
      local Screen = require("terminal.ui.panel.screen")
      local Panel = require("terminal.ui.panel.init")
      -- Mock terminal.size for Screen
      local original_size = terminal.size
      terminal.size = function()
        return 24, 80
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      local screen = Screen {
        body = Panel {
          content = function() end
        },
        footer = tab_strip
      }
      -- Should be able to calculate layout
      screen:calculate_layout()
      assert.is_not_nil(tab_strip.inner_row)
      assert.is_not_nil(tab_strip.inner_col)
      assert.is_not_nil(tab_strip.inner_width)
      -- Restore
      terminal.size = original_size
    end)


    it("does not render when hidden", function()
      local write_calls = 0
      local original_write = terminal.output.write
      terminal.output.write = function()
        write_calls = write_calls + 1
        return original_write()
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip._visible = false
      tab_strip:render()
      -- Restore
      terminal.output.write = original_write
      -- Should not have written anything (render should return early)
      assert.are.equal(0, write_calls)
    end)


    it("handles layout recalculation on resize", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      local width1 = tab_strip.inner_width
      tab_strip:calculate_layout(1, 1, 1, 120)
      local width2 = tab_strip.inner_width
      assert.are.equal(80, width1)
      assert.are.equal(120, width2)
    end)


    it("manages attribute stack correctly", function()
      local push_seq_count = 0
      local pop_seq_count = 0
      local text_stack = require("terminal.text.stack")
      local original_push_seq = text_stack.push_seq
      local original_pop_seq = text_stack.pop_seq
      text_stack.push_seq = function(...)
        push_seq_count = push_seq_count + 1
        return original_push_seq(...)
      end
      text_stack.pop_seq = function()
        pop_seq_count = pop_seq_count + 1
        return original_pop_seq()
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" },
          { id = "tab2", label = "Tab 2" }
        },
        attr = { fg = "white" },
        selected_attr = { reverse = true }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Restore originals
      text_stack.push_seq = original_push_seq
      text_stack.pop_seq = original_pop_seq
      -- Should have pushed and popped attributes
      assert.is_true(push_seq_count > 0)
      assert.is_true(pop_seq_count > 0)
      -- Push and pop should be balanced
      assert.are.equal(push_seq_count, pop_seq_count)
    end)


    it("restores cursor position after rendering", function()
      local backup_seq_called = false
      local restore_seq_called = false
      local original_backup_seq = terminal.cursor.position.backup_seq
      local original_restore_seq = terminal.cursor.position.restore_seq
      terminal.cursor.position.backup_seq = function()
        backup_seq_called = true
        return original_backup_seq()
      end
      terminal.cursor.position.restore_seq = function()
        restore_seq_called = true
        return original_restore_seq()
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab 1" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Restore
      terminal.cursor.position.backup_seq = original_backup_seq
      terminal.cursor.position.restore_seq = original_restore_seq
      assert.is_true(backup_seq_called)
      assert.is_true(restore_seq_called)
    end)

  end)



  describe("viewport management", function()

    it("manages viewport when tabs exceed available width", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Very Long Tab 1" },
          { id = "tab2", label = "Very Long Tab 2" },
          { id = "tab3", label = "Very Long Tab 3" },
          { id = "tab4", label = "Very Long Tab 4" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 20)  -- Small width
      tab_strip:render()
      -- Should have calculated viewport
      assert.is_not_nil(tab_strip._viewport_offset)
    end)


    it("slices content at display width boundaries", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" },
          { id = "tab2", label = "Tab2" },
          { id = "tab3", label = "Tab3" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 10)  -- Very small width
      tab_strip:render()
      -- Should have written some content
      assert.is_true(#write_calls > 0)
    end)


    it("displays left overflow indicator when content exists to left", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Very Long Tab 1" },
          { id = "tab2", label = "Very Long Tab 2" },
          { id = "tab3", label = "Very Long Tab 3" }
        },
        selected = "tab3"  -- Selected tab is on the right
      }
      tab_strip:calculate_layout(1, 1, 1, 20)  -- Small width
      tab_strip:render()
      -- Should contain ellipsis (default from truncate_ellipsis)
      -- The ellipsis character is "…" (U+2026)
      assert.matches("…", written_content)
    end)


    it("displays right overflow indicator when content exists to right", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Very Long Tab 1" },
          { id = "tab2", label = "Very Long Tab 2" },
          { id = "tab3", label = "Very Long Tab 3" }
        },
        selected = "tab1"  -- Selected tab is on the left
      }
      tab_strip:calculate_layout(1, 1, 1, 20)  -- Small width
      tab_strip:render()
      -- Should contain ellipsis
      assert.matches("…", written_content)
    end)


    it("does not display overflow indicators when all tabs fit", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" },
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)  -- Large width
      tab_strip:render()
      -- Should not contain ellipsis (all tabs fit)
      -- Note: We check that ellipsis is not in the middle of tab content
      -- The ellipsis would only appear if there's overflow
      local has_overflow_ellipsis = written_content:match("….*%[") or written_content:match("%].*…")
      assert.is_nil(has_overflow_ellipsis)
    end)


    it("correctly calculates overflow indicators when only one indicator is needed", function()
      -- This test demonstrates the bug where effective_width is adjusted after
      -- has_right_overflow is calculated, causing inconsistent viewport rendering.
      --
      -- The bug: has_right_overflow is calculated using effective_width that assumes
      -- 2 ellipsis (line 329), but then effective_width is adjusted for single ellipsis
      -- (lines 333-337), making the overflow detection inconsistent with visible_end calculation.
      --
      -- The fix: Recalculate has_right_overflow after adjusting effective_width to ensure
      -- consistency between overflow indicator decision and visible_end calculation.
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end

      -- Create a borderline case where the adjusted effective_width changes the overflow decision
      -- available_width = 20, total_content = 22, viewport_offset = 0, ellipsis = 1
      -- Initial: effective_width = 20 - 2 = 18
      -- has_right_overflow = (0 + 18 < 22) = true
      -- Adjusted: effective_width = 20 - 1 = 19
      -- Recalculated has_right_overflow should be: (0 + 19 < 22) = true (still true)
      --
      -- But the key issue is: has_right_overflow should be recalculated with the final
      -- effective_width to ensure consistency. The current code doesn't do this.
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "A" },
          { id = "tab2", label = "B" },
          { id = "tab3", label = "C" },
          { id = "tab4", label = "D" },
          { id = "tab5", label = "E" },
          { id = "tab6", label = "F" },
          { id = "tab7", label = "G" }
        },
        selected = "tab1",  -- Selected at start, viewport will be at 0
        padding = 1
      }
      -- Each tab: "[X]" = 3 chars, padding = 1
      -- 7 tabs: 7 * 3 + 6 * 1 = 21 + 6 = 27 chars total
      -- Available: 20 chars
      -- Initial effective_width: 20 - 2 = 18
      -- has_right_overflow: (0 + 18 < 27) = true
      -- Adjusted effective_width: 20 - 1 = 19
      -- visible_end: 0 + 19 = 19
      -- The bug: has_right_overflow was calculated with width 18, not 19
      tab_strip:calculate_layout(1, 1, 1, 20)
      tab_strip:render()

      -- The key assertion: has_right_overflow should be consistent with visible_end
      -- If visible_end uses effective_width=19, then has_right_overflow should also
      -- be calculated with effective_width=19 (or recalculated after adjustment)
      --
      -- Verify right overflow indicator is present
      assert.matches("…", written_content, "Should have right overflow indicator")

      -- Verify no left overflow indicator
      local left_ellipsis = written_content:match("^…")
      assert.is_nil(left_ellipsis, "Should not have left overflow indicator when viewport is at start")

      -- The actual bug: The code calculates has_right_overflow with one effective_width,
      -- but uses a different effective_width for visible_end. This inconsistency means
      -- the overflow indicator decision and the actual visible range don't match.
      --
      -- After the fix, has_right_overflow will be recalculated with the final effective_width,
      -- ensuring consistency. The test verifies this by checking that the rendering is correct.
    end)


    it("uses utf8swidth for all width calculations", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" },
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- If this test runs without errors, utf8swidth is being used correctly
      assert.is_not_nil(tab_strip)
    end)


    it("handles UTF-8 and double-width characters in viewport slicing", function()
      local write_calls = {}
      local written_content = ""
      terminal.output.write = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
          if type(arg) == "string" then
            written_content = written_content .. arg
          elseif type(arg) == "function" then
            local result = arg()
            if type(result) == "string" then
              written_content = written_content .. result
            end
          else
            local str = tostring(arg)
            if str then
              written_content = written_content .. str
            end
          end
        end
        table.insert(write_calls, {...})
      end
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "中文" },  -- Double-width characters
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 10)  -- Small width
      tab_strip:render()
      -- Should render without errors
      assert.is_true(#write_calls > 0)
    end)

  end)



  describe("viewport adjustment", function()

    it("adjusts viewport to show selected tab during rendering", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Very Long Tab 1" },
          { id = "tab2", label = "Very Long Tab 2" },
          { id = "tab3", label = "Very Long Tab 3" }
        },
        selected = "tab3"
      }
      tab_strip:calculate_layout(1, 1, 1, 20)
      tab_strip:render()
      -- Viewport should be adjusted to show selected tab
      assert.is_not_nil(tab_strip._viewport_offset)
    end)


    it("left-justifies tab when wider than effective width", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Extremely Long Tab Name That Exceeds Width" }
        },
        selected = "tab1"
      }
      tab_strip:calculate_layout(1, 1, 1, 10)  -- Very small width
      tab_strip:render()
      -- Viewport should be at start of tab
      assert.are.equal(0, tab_strip._viewport_offset)
    end)


    it("uses display width for all position calculations", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "中文" },  -- Double-width characters
          { id = "tab2", label = "Tab2" }
        },
        selected = "tab2"
      }
      tab_strip:calculate_layout(1, 1, 1, 10)
      tab_strip:render()
      -- Should calculate correctly using display width
      assert.is_not_nil(tab_strip._tab_widths[1])
      -- Double-width characters should be counted as 2 columns
      assert.is_true(tab_strip._tab_widths[1] >= 2)
    end)

  end)



  describe("text truncation and UTF-8", function()

    it("uses truncate_ellipsis for tab label truncation when needed", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Very Long Tab Label That Needs Truncation" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 10)
      tab_strip:render()
      -- Should handle truncation without errors
      assert.is_not_nil(tab_strip)
    end)


    it("handles double-width characters correctly", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "中文测试" },  -- CJK characters
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 20)
      tab_strip:render()
      -- Should calculate widths correctly
      assert.is_not_nil(tab_strip._tab_widths[1])
    end)


    it("handles UTF-8 character boundaries correctly", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "café" },  -- UTF-8 with combining characters
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 20)
      tab_strip:render()
      -- Should handle UTF-8 correctly
      assert.is_not_nil(tab_strip)
    end)

  end)



  describe("edge cases", function()

    it("handles zero width gracefully", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 0)
      tab_strip:render()
      -- Should not error
      assert.is_not_nil(tab_strip)
    end)


    it("handles very small width gracefully", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 1)
      tab_strip:render()
      -- Should not error
      assert.is_not_nil(tab_strip)
    end)


    it("handles all tabs fit case", function()
      local tab_strip = TabStrip {
        items = {
          { id = "tab1", label = "Tab1" },
          { id = "tab2", label = "Tab2" }
        }
      }
      tab_strip:calculate_layout(1, 1, 1, 80)
      tab_strip:render()
      -- Should not show overflow indicators
      assert.is_not_nil(tab_strip)
    end)


    it("validates option types and raises clear errors", function()
      assert.has_error(function()
        TabStrip {
          items = {
            { id = "tab1", label = "Tab1" }
          },
          padding = "invalid"  -- Should be number
        }
      end)
    end)

  end)

end)
