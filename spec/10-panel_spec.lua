describe("terminal.ui.panel", function()

  local Panel

  before_each(function()
    Panel = require("terminal.ui.panel")
  end)

  after_each(function()
    Panel = nil
  end)



  describe("init()", function()

    it("creates a content panel with callback", function()
      local callback_called = false
      local panel = Panel {
        content = function(self, row, col, height, width)
          callback_called = true
        end
      }

      assert.is_not_nil(panel)
      assert.is_not_nil(panel.content)
      assert.is_nil(panel.children)
      assert.is_nil(panel.orientation)

      -- Call the panel's content callback to test it
      panel:content(1, 1, 10, 20)
      assert.is_true(callback_called, "Content callback should have been called")
    end)


    it("creates a divided panel with horizontal orientation", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      assert.is_not_nil(panel)
      assert.is_nil(panel.content)
      assert.is_not_nil(panel.children)
      assert.are.equal(Panel.orientations.horizontal, panel.orientation)
      assert.are.equal(2, #panel.children)
    end)


    it("creates a divided panel with vertical orientation", function()
      local top_panel = Panel { content = function() end }
      local bottom_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.vertical,
        children = { top_panel, bottom_panel }
      }

      assert.is_not_nil(panel)
      assert.is_nil(panel.content)
      assert.is_not_nil(panel.children)
      assert.are.equal(Panel.orientations.vertical, panel.orientation)
      assert.are.equal(2, #panel.children)
    end)


    it("sets default split ratio to 0.5", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      assert.are.equal(0.5, panel.split_ratio)
    end)


    it("sets custom split ratio", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        split_ratio = 0.7,
        children = { left_panel, right_panel }
      }

      assert.are.equal(0.7, panel.split_ratio)
    end)


    it("sets default size constraints", function()
      local panel = Panel { content = function() end }

      assert.are.equal(1, panel:get_min_height())
      assert.are.equal(1, panel:get_min_width())
      assert.are.equal(math.huge, panel:get_max_height())
      assert.are.equal(math.huge, panel:get_max_width())
    end)


    it("sets custom size constraints on content panels", function()
      local panel = Panel {
        content = function() end,
        min_height = 5,
        min_width = 10,
        max_height = 20,
        max_width = 50
      }

      assert.are.equal(5, panel:get_min_height())
      assert.are.equal(10, panel:get_min_width())
      assert.are.equal(20, panel:get_max_height())
      assert.are.equal(50, panel:get_max_width())
    end)


    it("derives constraints from children for split panels", function()
      local left_panel = Panel {
        content = function() end,
        min_height = 3,
        min_width = 8,
        max_height = 10,
        max_width = 15
      }
      local right_panel = Panel {
        content = function() end,
        min_height = 4,
        min_width = 6,
        max_height = 12,
        max_width = 18
      }
      local split_panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      -- Calculate layout to trigger constraint derivation
      split_panel:calculate_layout(1, 1, 20, 30)

      -- For horizontal split: width = sum of children, height = min of children
      assert.are.equal(4, split_panel:get_min_height()) -- max(3, 4)
      assert.are.equal(10, split_panel:get_max_height()) -- min(10, 12)
      assert.are.equal(14, split_panel:get_min_width()) -- 8 + 6
      assert.are.equal(33, split_panel:get_max_width()) -- 15 + 18
    end)


    it("respects maximum size constraints in layout calculation", function()
      local panel = Panel {
        orientation = Panel.orientations.vertical,
        children = {
          Panel {
            content = function(self, row, col, height, width)
              -- Test content
            end,
            max_height = 1  -- Maximum 1 row
          },
          Panel {
            content = function(self, row, col, height, width)
              -- Test content
            end
            -- No size constraints
          }
        }
      }

      panel:calculate_layout(1, 1, 10, 80)

      -- First child should be limited to max_height
      assert.are.equal(1, panel.children[1].height)

      -- Second child should get the remaining space
      assert.are.equal(9, panel.children[2].height)

      -- Total height should be preserved
      assert.are.equal(10, panel.children[1].height + panel.children[2].height)
    end)


    it("respects maximum width constraints in horizontal layout", function()
      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = {
          Panel {
            content = function(self, row, col, height, width)
              -- Test content
            end,
            max_width = 20  -- Maximum 20 columns
          },
          Panel {
            content = function(self, row, col, height, width)
              -- Test content
            end
            -- No size constraints
          }
        }
      }

      panel:calculate_layout(1, 1, 5, 80)

      -- First child should be limited to max_width
      assert.are.equal(20, panel.children[1].width)

      -- Second child should get the remaining space
      assert.are.equal(60, panel.children[2].width)

      -- Total width should be preserved
      assert.are.equal(80, panel.children[1].width + panel.children[2].width)
    end)


    it("throws error when neither content nor children provided", function()
      assert.has.error(function()
        Panel {}
      end, "Panel must have either content callback or children")
    end)


    it("throws error when both content and children provided", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      assert.has.error(function()
        Panel {
          content = function() end,
          children = { left_panel, right_panel }
        }
      end, "Panel cannot have both content and children")
    end)


    it("throws error when divided panel has wrong number of children", function()
      local left_panel = Panel { content = function() end }

      assert.has.error(function()
        Panel {
          orientation = Panel.orientations.horizontal,
          children = { left_panel }
        }
      end, "Divided panel must have exactly 2 children")
    end)


    it("throws error when divided panel has invalid orientation", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      assert.has.error(function()
        Panel {
          orientation = "diagonal",
          children = { left_panel, right_panel }
        }
      end, 'Invalid orientation: diagonal. Must be Panel.orientations.horizontal or Panel.orientations.vertical')
    end)


    it("throws error when split ratio is out of range", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      assert.has.error(function()
        Panel {
          orientation = Panel.orientations.horizontal,
          split_ratio = 1.5,
          children = { left_panel, right_panel }
        }
      end, "Split ratio must be between 0.0 and 1.0")
    end)


    it("uses provided name for content panel", function()
      local panel = Panel {
        content = function() end,
        name = "my-content-panel"
      }

      assert.are.equal("my-content-panel", panel.name)
    end)


    it("uses provided name for divided panel", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel },
        name = "my-divided-panel"
      }

      assert.are.equal("my-divided-panel", panel.name)
    end)


    it("defaults to tostring(self) when no name provided", function()
      local panel = Panel { content = function() end }
      local expected_name = tostring(panel)

      assert.are.equal(expected_name, panel.name)
    end)


    it("defaults to tostring(self) for divided panel when no name provided", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }
      local expected_name = tostring(panel)

      assert.are.equal(expected_name, panel.name)
    end)

  end)



  describe("calculate_layout()", function()

    it("calculates layout for content panel", function()
      local panel = Panel { content = function() end }

      panel:calculate_layout(5, 10, 8, 20)

      assert.are.equal(5, panel.row)
      assert.are.equal(10, panel.col)
      assert.are.equal(8, panel.height)
      assert.are.equal(20, panel.width)
    end)


    it("applies size constraints", function()
      local panel = Panel {
        content = function() end,
        min_height = 5,
        min_width = 10,
        max_height = 15,
        max_width = 25
      }

      panel:calculate_layout(1, 1, 3, 5) -- below minimum
      assert.are.equal(5, panel.height)
      assert.are.equal(10, panel.width)

      panel:calculate_layout(1, 1, 20, 30) -- above maximum
      assert.are.equal(15, panel.height)
      assert.are.equal(25, panel.width)
    end)


    it("calculates horizontal division layout", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        split_ratio = 0.6,
        children = { left_panel, right_panel }
      }

      panel:calculate_layout(1, 1, 10, 20)

      -- Parent panel
      assert.are.equal(1, panel.row)
      assert.are.equal(1, panel.col)
      assert.are.equal(10, panel.height)
      assert.are.equal(20, panel.width)

      -- Left panel (60% of width)
      assert.are.equal(1, left_panel.row)
      assert.are.equal(1, left_panel.col)
      assert.are.equal(10, left_panel.height)
      assert.are.equal(12, left_panel.width) -- 60% of 20

      -- Right panel (40% of width)
      assert.are.equal(1, right_panel.row)
      assert.are.equal(13, right_panel.col) -- 1 + 12
      assert.are.equal(10, right_panel.height)
      assert.are.equal(8, right_panel.width) -- 40% of 20
    end)


    it("calculates vertical division layout", function()
      local top_panel = Panel { content = function() end }
      local bottom_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.vertical,
        split_ratio = 0.4,
        children = { top_panel, bottom_panel }
      }

      panel:calculate_layout(1, 1, 10, 20)

      -- Parent panel
      assert.are.equal(1, panel.row)
      assert.are.equal(1, panel.col)
      assert.are.equal(10, panel.height)
      assert.are.equal(20, panel.width)

      -- Top panel (40% of height)
      assert.are.equal(1, top_panel.row)
      assert.are.equal(1, top_panel.col)
      assert.are.equal(4, top_panel.height) -- 40% of 10
      assert.are.equal(20, top_panel.width)

      -- Bottom panel (60% of height)
      assert.are.equal(5, bottom_panel.row) -- 1 + 4
      assert.are.equal(1, bottom_panel.col)
      assert.are.equal(6, bottom_panel.height) -- 60% of 10
      assert.are.equal(20, bottom_panel.width)
    end)


    it("respects minimum width constraints in horizontal division", function()
      local left_panel = Panel {
        content = function() end,
        min_width = 8
      }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        split_ratio = 0.1, -- would give left panel only 1 column
        children = { left_panel, right_panel }
      }

      panel:calculate_layout(1, 1, 10, 20)

      assert.are.equal(8, left_panel.width) -- minimum width enforced
      assert.are.equal(12, right_panel.width) -- remaining space
    end)


    it("respects minimum height constraints in vertical division", function()
      local top_panel = Panel {
        content = function() end,
        min_height = 3
      }
      local bottom_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.vertical,
        split_ratio = 0.1, -- would give top panel only 1 row
        children = { top_panel, bottom_panel }
      }

      panel:calculate_layout(1, 1, 10, 20)

      assert.are.equal(3, top_panel.height) -- minimum height enforced
      assert.are.equal(7, bottom_panel.height) -- remaining space
    end)

  end)






  describe("get_size()", function()

    it("returns height and width for any panel", function()
      local panel = Panel { content = function() end }

      panel:calculate_layout(1, 1, 10, 20)

      local height, width = panel:get_size()
      assert.are.equal(10, height)
      assert.are.equal(20, width)
    end)

  end)



  describe("set_split_ratio()", function()

    it("sets split ratio for divided panel", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      panel:set_split_ratio(0.8)

      assert.are.equal(0.8, panel.split_ratio)
    end)


    it("throws error when setting split ratio on content panel", function()
      local panel = Panel { content = function() end }

      assert.has.error(function()
        panel:set_split_ratio(0.5)
      end, "Split ratio can only be set on divided panels")
    end)


    it("throws error when split ratio is out of range", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      assert.has.error(function()
        panel:set_split_ratio(1.5)
      end, "Split ratio must be between 0.0 and 1.0")
    end)

  end)



  describe("render()", function()

    local terminal, old_size
    before_each(function()
      terminal = require("terminal")
      old_size = terminal.size
      terminal.size = function() return 24, 80 end
    end)

    after_each(function()
      terminal.size = old_size
      terminal = nil
      old_size = nil
    end)


    it("calls content callback for content panel", function()
      local callback_called = false
      local callback_args = {}

      local panel = Panel {
        content = function(self, row, col, height, width)
          callback_called = true
          callback_args = { self, row, col, height, width }
        end
      }

      panel:calculate_layout(2, 3, 5, 10)
      panel:render()

      assert.is_true(callback_called)
      assert.are.equal(panel, callback_args[1])
      callback_args[1] = nil
      assert.are.same({nil, 2, 3, 5, 10}, callback_args)
    end)


    it("renders child panels for divided panel", function()
      local left_callback_called = false
      local right_callback_called = false

      local left_panel = Panel {
        content = function(self, row, col, height, width)
          left_callback_called = true
        end
      }

      local right_panel = Panel {
        content = function(self, row, col, height, width)
          right_callback_called = true
        end
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      panel:calculate_layout(1, 1, 5, 10)
      panel:render()

      assert.is_true(left_callback_called)
      assert.is_true(right_callback_called)
    end)

  end)






  describe("get_type()", function()

    it("returns 'content' for content panel", function()
      local panel = Panel { content = function() end }

      assert.are.equal("content", panel:get_type())
    end)


    it("returns orientation for divided panel", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local horizontal_panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      local top_panel = Panel { content = function() end }
      local bottom_panel = Panel { content = function() end }

      local vertical_panel = Panel {
        orientation = Panel.orientations.vertical,
        children = { top_panel, bottom_panel }
      }

      assert.are.equal(Panel.orientations.horizontal, horizontal_panel:get_type())
      assert.are.equal(Panel.orientations.vertical, vertical_panel:get_type())
    end)

  end)






  describe("get_children()", function()

    it("returns nil for content panel", function()
      local panel = Panel { content = function() end }

      assert.is_nil(panel:get_children())
    end)


    it("returns children for divided panel", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel }
      }

      local children = panel:get_children()

      assert.is_not_nil(children)
      assert.are.equal(2, #children)
      assert.are.equal(left_panel, children[1])
      assert.are.equal(right_panel, children[2])
    end)

  end)



  describe("get_split_ratio()", function()

    it("returns nil for content panel", function()
      local panel = Panel { content = function() end }

      assert.is_nil(panel:get_split_ratio())
    end)


    it("returns split ratio for divided panel", function()
      local left_panel = Panel { content = function() end }
      local right_panel = Panel { content = function() end }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        split_ratio = 0.7,
        children = { left_panel, right_panel }
      }

      assert.are.equal(0.7, panel:get_split_ratio())
    end)

  end)









  describe("get_panel()", function()

    it("returns self when name matches", function()
      local panel = Panel {
        content = function() end,
        name = "test-panel"
      }

      local found = panel:get_panel("test-panel")

      assert.are.equal(panel, found)
    end)


    it("returns nil when name does not match", function()
      local panel = Panel {
        content = function() end,
        name = "test-panel"
      }

      local found = panel:get_panel("other-panel")

      assert.is_nil(found)
    end)


    it("finds child panel by name in divided panel", function()
      local left_panel = Panel {
        content = function() end,
        name = "left-panel"
      }
      local right_panel = Panel {
        content = function() end,
        name = "right-panel"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel },
        name = "parent-panel"
      }

      local found_left = panel:get_panel("left-panel")
      local found_right = panel:get_panel("right-panel")
      local found_parent = panel:get_panel("parent-panel")

      assert.are.equal(left_panel, found_left)
      assert.are.equal(right_panel, found_right)
      assert.are.equal(panel, found_parent)
    end)


    it("finds panel in nested structure", function()
      local nested_left = Panel {
        content = function() end,
        name = "nested-left"
      }
      local nested_right = Panel {
        content = function() end,
        name = "nested-right"
      }

      local nested_panel = Panel {
        orientation = Panel.orientations.vertical,
        children = { nested_left, nested_right },
        name = "nested-parent"
      }

      local right_panel = Panel {
        content = function() end,
        name = "right-panel"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { nested_panel, right_panel },
        name = "root-panel"
      }

      local found_nested_left = panel:get_panel("nested-left")
      local found_nested_right = panel:get_panel("nested-right")
      local found_right = panel:get_panel("right-panel")
      local found_nested_parent = panel:get_panel("nested-parent")
      local found_root = panel:get_panel("root-panel")

      assert.are.equal(nested_left, found_nested_left)
      assert.are.equal(nested_right, found_nested_right)
      assert.are.equal(right_panel, found_right)
      assert.are.equal(nested_panel, found_nested_parent)
      assert.are.equal(panel, found_root)
    end)


    it("returns first match when multiple panels have same name", function()
      local left_panel = Panel {
        content = function() end,
        name = "duplicate-name"
      }
      local right_panel = Panel {
        content = function() end,
        name = "duplicate-name"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel },
        name = "parent-panel"
      }

      local found = panel:get_panel("duplicate-name")

      -- Should return the first child (left_panel) since we check children in order
      assert.are.equal(left_panel, found)
    end)

  end)


  describe("panels property", function()

    it("is empty for content panels", function()
      local panel = Panel {
        content = function() end,
        name = "content-panel"
      }

      assert.are.same({}, panel.panels)
    end)


    it("lazy-loads child panels by name", function()
      local left_panel = Panel {
        content = function() end,
        name = "left-panel"
      }
      local right_panel = Panel {
        content = function() end,
        name = "right-panel"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel },
        name = "parent-panel"
      }

      -- Initially empty
      assert.are.same({}, panel.panels)

      -- Access left panel - should lazy-load
      local found_left = panel.panels["left-panel"]
      assert.are.equal(left_panel, found_left)

      -- Access right panel - should lazy-load
      local found_right = panel.panels["right-panel"]
      assert.are.equal(right_panel, found_right)

      -- Access non-existent panel - should return nil
      local not_found = panel.panels["nonexistent"]
      assert.is_nil(not_found)
    end)


    it("caches loaded panels", function()
      local left_panel = Panel {
        content = function() end,
        name = "left-panel"
      }
      local right_panel = Panel {
        content = function() end,
        name = "right-panel"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { left_panel, right_panel },
        name = "parent-panel"
      }

      -- Access panel multiple times
      local found1 = panel.panels["left-panel"]
      local found2 = panel.panels["left-panel"]

      assert.are.equal(left_panel, found1)
      assert.are.equal(left_panel, found2)
      assert.are.equal(found1, found2) -- Same reference
    end)


    it("works with nested panel structures", function()
      local nested_left = Panel {
        content = function() end,
        name = "nested-left"
      }
      local nested_right = Panel {
        content = function() end,
        name = "nested-right"
      }

      local nested_panel = Panel {
        orientation = Panel.orientations.vertical,
        children = { nested_left, nested_right },
        name = "nested-parent"
      }

      local right_panel = Panel {
        content = function() end,
        name = "right-panel"
      }

      local panel = Panel {
        orientation = Panel.orientations.horizontal,
        children = { nested_panel, right_panel },
        name = "root-panel"
      }

      -- Access nested panel (direct child)
      local found_nested = panel.panels["nested-parent"]
      assert.are.equal(nested_panel, found_nested)

      -- Access leaf panel (direct child)
      local found_right = panel.panels["right-panel"]
      assert.are.equal(right_panel, found_right)

      -- Access deeply nested panel (grandchild)
      local found_nested_left = panel.panels["nested-left"]
      assert.are.equal(nested_left, found_nested_left)

      local found_nested_right = panel.panels["nested-right"]
      assert.are.equal(nested_right, found_nested_right)

      -- Access non-existent panel
      local not_found = panel.panels["nonexistent"]
      assert.is_nil(not_found)
    end)


    it("returns nil for content panels when accessing panels", function()
      local panel = Panel {
        content = function() end,
        name = "content-panel"
      }

      local not_found = panel.panels["any-name"]
      assert.is_nil(not_found)
    end)

  end)

end)
