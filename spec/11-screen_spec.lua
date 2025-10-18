#!/usr/bin/env lua

--- Tests for terminal.ui.screen module
-- @module spec.11-screen_spec

describe("terminal.ui.screen", function()

  local Screen
  local Panel
  local terminal

  before_each(function()
    Screen = require("terminal.ui.panel.screen")
    Panel = require("terminal.ui.panel")
    terminal = require("terminal")
  end)

  after_each(function()
    Screen = nil
    Panel = nil
    terminal = nil
  end)


  describe("init()", function()

    it("creates a screen with body panel only", function()
      local body = Panel {
        content = function(self)
          -- Test content
        end
      }

      local screen = Screen {
        body = body
      }

      assert.is_not_nil(screen)
      assert.are.equal(screen.panels.body, body)
      assert.is_nil(screen.panels.header)
      assert.is_nil(screen.panels.footer)
      assert.are.equal(Panel.orientations.vertical, screen.orientation)
      assert.are.equal(2, #screen.children)
      assert.are.equal(body, screen.children[1])
      -- Second child should be a dummy panel
      local dummy_panel = screen.children[2]
      assert.are.equal("content", dummy_panel:get_type())
    end)


    it("creates a screen with header, body, and footer", function()
      local header = Panel {
        content = function(self)
          -- Header content
        end
      }

      local body = Panel {
        content = function(self)
          -- Body content
        end
      }

      local footer = Panel {
        content = function(self)
          -- Footer content
        end
      }

      local screen = Screen {
        header = header,
        body = body,
        footer = footer
      }

      assert.is_not_nil(screen)
      assert.are.equal(screen.panels.header, header)
      assert.are.equal(screen.panels.body, body)
      assert.are.equal(screen.panels.footer, footer)
      assert.are.equal(Panel.orientations.vertical, screen.orientation)
      assert.are.equal(2, #screen.children)
      assert.are.equal(header, screen.children[1])
      -- Second child should be a vertical panel containing body and footer
      local body_footer_panel = screen.children[2]
      assert.are.equal(Panel.orientations.vertical, body_footer_panel.orientation)
      assert.are.equal(2, #body_footer_panel.children)
      assert.are.equal(body, body_footer_panel.children[1])
      assert.are.equal(footer, body_footer_panel.children[2])
    end)


    it("creates a screen with header and body only", function()
      local header = Panel {
        content = function(self)
          -- Header content
        end
      }

      local body = Panel {
        content = function(self)
          -- Body content
        end
      }

      local screen = Screen {
        header = header,
        body = body
      }

      assert.is_not_nil(screen)
      assert.are.equal(screen.panels.header, header)
      assert.are.equal(screen.panels.body, body)
      assert.is_nil(screen.panels.footer)
      assert.are.equal(Panel.orientations.vertical, screen.orientation)
      assert.are.equal(2, #screen.children)
      assert.are.equal(header, screen.children[1])
      assert.are.equal(body, screen.children[2])
    end)


    it("creates a screen with body and footer only", function()
      local body = Panel {
        content = function(self)
          -- Body content
        end
      }

      local footer = Panel {
        content = function(self)
          -- Footer content
        end
      }

      local screen = Screen {
        body = body,
        footer = footer
      }

      assert.is_not_nil(screen)
      assert.is_nil(screen.panels.header)
      assert.are.equal(screen.panels.body, body)
      assert.are.equal(screen.panels.footer, footer)
      assert.are.equal(Panel.orientations.vertical, screen.orientation)
      assert.are.equal(2, #screen.children)
      assert.are.equal(body, screen.children[1])
      assert.are.equal(footer, screen.children[2])
    end)


    it("throws error when body panel is not provided", function()
      assert.has_error(function()
        Screen {}
      end, "Screen requires a body panel")
    end)


    it("accepts custom name", function()
      local body = Panel {
        content = function(self)
          -- Test content
        end
      }

      local screen = Screen {
        body = body,
        name = "MyScreen"
      }

      assert.are.equal("MyScreen", screen.name)
    end)


    it("allows access to panels by name", function()
      local header = Panel {
        content = function(self)
          -- Header content
        end
      }

      local body = Panel {
        content = function(self)
          -- Body content
        end
      }

      local footer = Panel {
        content = function(self)
          -- Footer content
        end
      }

      local screen = Screen {
        header = header,
        body = body,
        footer = footer
      }

      -- Test panel access by name
      assert.are.equal(header, screen.panels.header)
      assert.are.equal(body, screen.panels.body)
      assert.are.equal(footer, screen.panels.footer)

      -- Test that panels have correct names
      assert.are.equal("header", header.name)
      assert.are.equal("body", body.name)
      assert.are.equal("footer", footer.name)
    end)

  end)


  describe("check_resize()", function()

    it("returns false when terminal size has not changed", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal.size to return consistent values
      local original_size = terminal.size
      terminal.size = function() return 24, 80 end

      -- Reset the screen's internal size tracking
      screen._last_height, screen._last_width = 24, 80

      local was_resized = screen:check_resize()
      assert.is_false(was_resized)

      terminal.size = original_size
    end)


    it("returns true when terminal size has changed", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal.size to return different values
      local original_size = terminal.size
      terminal.size = function() return 30, 100 end -- Different from initial size

      local was_resized = screen:check_resize()
      assert.is_true(was_resized)

      terminal.size = original_size
    end)


    it("updates layout when update is true and terminal was resized", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal.size
      local original_size = terminal.size
      terminal.size = function() return 30, 100 end -- Different from initial size

      local was_resized = screen:check_resize(true)
      assert.is_true(was_resized)

      terminal.size = original_size
    end)


    it("does not update layout when update is false", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal.size and terminal.clear
      local original_size = terminal.size
      local original_clear = terminal.clear
      local clear_called = false

      terminal.clear = function() clear_called = true end

      local call_count = 0
      terminal.size = function()
        call_count = call_count + 1
        if call_count == 1 then
          return 24, 80  -- Initial size
        else
          return 30, 100 -- Resized
        end
      end

      local was_resized = screen:check_resize(false)
      assert.is_true(was_resized)
      assert.is_false(clear_called)

      terminal.size = original_size
      terminal.clear = original_clear
    end)

  end)


  describe("recalculate()", function()

    it("recalculates layout using current terminal dimensions", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal.size
      local original_size = terminal.size
      terminal.size = function() return 30, 100 end

      screen:calculate_layout()

      -- Check that the screen has the correct dimensions
      assert.are.equal(1, screen.row)
      assert.are.equal(1, screen.col)
      assert.are.equal(30, screen.height)
      assert.are.equal(100, screen.width)

      terminal.size = original_size
    end)

  end)


  describe("render()", function()

    it("renders all panels", function()
      local body = Panel {
        content = function(self, row, col, height, width)
          -- Test content
        end
      }

      local screen = Screen { body = body }

      -- Mock terminal functions
      local original_size = terminal.size
      terminal.size = function() return 24, 80 end

      screen:calculate_layout()
      screen:render()

      -- Just verify that render doesn't error
      assert.is_true(true)

      terminal.size = original_size
    end)

  end)


  describe("integration", function()

    it("works with a complete screen layout", function()
      local header = Panel {
        content = function(self, row, col, height, width)
          -- Header content
        end
      }

      local body = Panel {
        content = function(self, row, col, height, width)
          -- Body content
        end
      }

      local footer = Panel {
        content = function(self, row, col, height, width)
          -- Footer content
        end
      }

      local screen = Screen {
        header = header,
        body = body,
        footer = footer,
        name = "TestScreen"
      }

      -- Mock terminal functions
      local original_size = terminal.size
      local original_clear = terminal.clear

      terminal.size = function() return 25, 80 end
      terminal.clear = {
        box = function() end
      }

      -- Test that the screen can be recalculated and rendered
      screen:calculate_layout()
      screen:render()

      -- Verify the screen structure
      assert.are.equal("TestScreen", screen.name)
      assert.are.equal(header, screen.panels.header)
      assert.are.equal(body, screen.panels.body)
      assert.are.equal(footer, screen.panels.footer)
      assert.are.equal(Panel.orientations.vertical, screen.orientation)
      assert.are.equal(2, #screen.children)
      assert.are.equal(header, screen.children[1])
      -- Second child should be a vertical panel containing body and footer
      local body_footer_panel = screen.children[2]
      assert.are.equal(Panel.orientations.vertical, body_footer_panel.orientation)
      assert.are.equal(2, #body_footer_panel.children)
      assert.are.equal(body, body_footer_panel.children[1])
      assert.are.equal(footer, body_footer_panel.children[2])

      terminal.size = original_size
      terminal.clear = original_clear
    end)

  end)

end)
