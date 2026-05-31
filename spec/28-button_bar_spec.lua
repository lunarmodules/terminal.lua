local helpers = require "spec.helpers"


describe("terminal.ui.panel.button_bar", function()

  local ButtonBar
  local utils
  local textwidth

  setup(function()
    helpers.load()
    ButtonBar  = require("terminal.ui.panel.button_bar")
    utils      = require("terminal.utils")
    textwidth  = require("terminal.text.width")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a ButtonBar deriving from Panel", function()
      local Panel = require("terminal.ui.panel.init")
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(Panel.types.content, bar:get_type())
    end)


    it("has fixed height of 1 line with no padding options set", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(1, bar:get_min_height())
      assert.are.equal(1, bar:get_max_height())
    end)


    it("uses Panel's content callback mechanism", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.is_function(bar.content)
    end)


    it("raises error when items table is missing", function()
      assert.has_error(function()
        ButtonBar { }
      end)
    end)


    it("raises error when any item is missing the label field", function()
      assert.has_error(function()
        ButtonBar { items = { { id = "ok" } } }
      end)
    end)


    it("raises error when more than one item has cancel = true", function()
      assert.has_error(function()
        ButtonBar {
          items = {
            {
              label = "Yes",
              cancel = true,
            },
            {
              label = "No",
              cancel = true,
            },
          }
        }
      end)
    end)

  end)



  describe("ids and sets", function()

    it("exposes ids as string constants", function()
      assert.are.equal("yes",    ButtonBar.ids.yes)
      assert.are.equal("no",     ButtonBar.ids.no)
      assert.are.equal("cancel", ButtonBar.ids.cancel)
      assert.are.equal("ok",     ButtonBar.ids.ok)
    end)


    it("preset sets can be passed directly as items", function()
      local bar = ButtonBar { items = ButtonBar.sets.yes_no }
      assert.are.equal(2, #bar.items)
      assert.are.equal("Yes", bar.items[1].label)
      assert.are.equal("No",  bar.items[2].label)
    end)


    it("preset set ids match ButtonBar.ids values", function()
      local bar = ButtonBar { items = ButtonBar.sets.yes_no }
      assert.are.equal(ButtonBar.ids.yes, bar.items[1].id)
      assert.are.equal(ButtonBar.ids.no,  bar.items[2].id)
    end)


    it("cancel flag from preset set is preserved", function()
      local bar = ButtonBar { items = ButtonBar.sets.yes_no_cancel }
      assert.is_not_nil(bar.cancel_idx)
      assert.are.equal(ButtonBar.ids.cancel, bar.items[bar.cancel_idx].id)
    end)


    it("select_cancel returns the cancel id from ButtonBar.ids", function()
      local bar = ButtonBar {
        items = ButtonBar.sets.yes_no_cancel,
        selected = ButtonBar.ids.yes,
      }
      local id = bar:select_cancel()
      assert.are.equal(ButtonBar.ids.cancel, id)
    end)

  end)



  describe("items handling", function()

    it("assigns default ids (1-based index) when id field is omitted", function()
      local bar = ButtonBar {
        items = {
          { label = "Yes" },
          { label = "No" },
          { label = "Cancel" },
        }
      }
      assert.are.equal(1, bar.items[1].id)
      assert.are.equal(2, bar.items[2].id)
      assert.are.equal(3, bar.items[3].id)
    end)


    it("preserves explicit ids when provided", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        }
      }
      assert.are.equal("yes", bar.items[1].id)
      assert.are.equal("no",  bar.items[2].id)
    end)


    it("stores the cancel flag on the correct item", function()
      local bar = ButtonBar {
        items = {
          { label = "Yes" },
          {
            label = "Cancel",
            cancel = true,
          },
        }
      }
      assert.are.equal(2, bar.cancel_idx)
      assert.is_true(bar.items[2].cancel)
      assert.is_false(bar.items[1].cancel)
    end)


    it("accepts items with no cancel entry", function()
      local bar = ButtonBar {
        items = {
          { label = "Yes" },
          { label = "No" },
        }
      }
      assert.is_nil(bar.cancel_idx)
    end)


    it("accepts a single item", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(1, #bar.items)
      assert.are.equal("OK", bar.items[1].label)
    end)

  end)



  describe("configuration parameters", function()

    it("uses '[' as default prefix", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal("[", bar.prefix)
    end)


    it("uses ']' as default postfix", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal("]", bar.postfix)
    end)


    it("accepts a custom prefix and postfix", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        prefix = "<",
        postfix = ">",
      }
      assert.are.equal("<", bar.prefix)
      assert.are.equal(">", bar.postfix)
    end)


    it("uses 1 as default padding between buttons", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(1, bar.padding)
    end)


    it("accepts a custom padding value", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        padding = 3,
      }
      assert.are.equal(3, bar.padding)
    end)


    it("accepts button_min_width and stores it, defaults to 1", function()
      local bar1 = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(1, bar1.button_min_width)
      local bar2 = ButtonBar {
        items = { { label = "OK" } },
        button_min_width = 10,
      }
      assert.are.equal(10, bar2.button_min_width)
    end)


    it("accepts button_max_width and stores it, defaults to math.huge", function()
      local bar1 = ButtonBar { items = { { label = "OK" } } }
      assert.are.equal(math.huge, bar1.button_max_width)
      local bar2 = ButtonBar {
        items = { { label = "OK" } },
        button_max_width = 20,
      }
      assert.are.equal(20, bar2.button_max_width)
    end)


    it("accepts attr for bar background styling", function()
      local attr = {
        fg = "white",
        bg = "blue",
      }
      local bar = ButtonBar {
        items = { { label = "OK" } },
        attr = attr,
      }
      assert.are.same(attr, bar.attr)
    end)


    it("accepts button_attr for unselected button styling", function()
      local button_attr = { fg = "yellow" }
      local bar = ButtonBar {
        items = { { label = "OK" } },
        button_attr = button_attr,
      }
      assert.are.same(button_attr, bar.button_attr)
    end)


    it("accepts selected_attr for focused button styling", function()
      local selected_attr = { reverse = true }
      local bar = ButtonBar {
        items = { { label = "OK" } },
        selected_attr = selected_attr,
      }
      assert.are.same(selected_attr, bar.selected_attr)
    end)


    it("defaults auto_render to false", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      assert.is_false(bar.auto_render)
    end)


    it("stores auto_render as true when set", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        auto_render = true,
      }
      assert.is_true(bar.auto_render)
    end)

  end)



  describe("attribute auto-derivation", function()

    it("derives button_attr from attr by inverting the reverse field when button_attr is omitted", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        attr = {
          fg = "white",
          bg = "blue",
          reverse = false,
        },
      }
      assert.is_not_nil(bar.button_attr)
      assert.are.equal("white", bar.button_attr.fg)
      assert.are.equal("blue",  bar.button_attr.bg)
      assert.is_true(bar.button_attr.reverse)
    end)


    it("derives selected_attr from button_attr by inverting the reverse field when selected_attr is omitted", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        button_attr = {
          fg = "yellow",
          reverse = false,
        },
      }
      assert.is_not_nil(bar.selected_attr)
      assert.are.equal("yellow", bar.selected_attr.fg)
      assert.is_true(bar.selected_attr.reverse)
    end)


    it("does not derive selected_attr from attr directly; button_attr is the only source", function()
      -- attr has no reverse field (nil); derivation chain: nil -> true -> false
      local bar = ButtonBar {
        items = { { label = "OK" } },
        attr = { fg = "red" },
      }
      -- button_attr.reverse: not nil = true
      assert.is_true(bar.button_attr.reverse)
      -- selected_attr.reverse: not true = false  (not nil=true as it would be if derived from attr directly)
      assert.is_false(bar.selected_attr.reverse)
    end)


    it("uses explicit button_attr unchanged when provided alongside attr", function()
      local explicit = {
        fg = "green",
        reverse = false,
      }
      local bar = ButtonBar {
        items = { { label = "OK" } },
        attr = {
          fg = "white",
          reverse = true,
        },
        button_attr = explicit,
      }
      assert.are.same(explicit, bar.button_attr)
    end)


    it("uses explicit selected_attr unchanged when provided alongside button_attr", function()
      local explicit = {
        fg = "cyan",
        reverse = true,
      }
      local bar = ButtonBar {
        items = { { label = "OK" } },
        button_attr = {
          fg = "yellow",
          reverse = false,
        },
        selected_attr = explicit,
      }
      assert.are.same(explicit, bar.selected_attr)
    end)


    it("falls back to { reverse = true } for selected_attr when no attrs are provided", function()
      local bar = ButtonBar {
        items = { { label = "OK" }, { label = "Cancel" } },
      }
      assert.is_nil(bar.attr)
      assert.is_nil(bar.button_attr)
      assert.are.same({ reverse = true }, bar.selected_attr)
    end)

  end)



  describe("initial selection", function()

    it("defaults to the first item when selected is not provided", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        }
      }
      assert.are.equal("yes", bar.selected)
    end)


    it("accepts selected id and focuses that button", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "no",
      }
      assert.are.equal("no", bar.selected)
    end)


    it("raises error when the provided selected id is not found in items", function()
      assert.has_error(function()
        ButtonBar {
          items = {
            {
              id = "yes",
              label = "Yes",
            },
            {
              id = "no",
              label = "No",
            },
          },
          selected = "nonexistent",
        }
      end)
    end)

  end)



  describe("get_selection()", function()

    it("returns the id of the initially focused button", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "no",
      }
      assert.are.equal("no", bar:get_selection())
    end)


    it("returns the updated id after selection changes", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      bar:select("no")
      assert.are.equal("no", bar:get_selection())
    end)

  end)



  describe("select()", function()

    it("moves focus to the button with the given id and returns it", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      local id, err = bar:select("no")
      assert.are.equal("no", id)
      assert.is_nil(err)
      assert.are.equal("no", bar:get_selection())
    end)


    it("returns the current selection and an error string when the id is not found", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      local id, err = bar:select("nonexistent")
      assert.are.equal("yes", id)
      assert.is_not_nil(err)
    end)


    it("does not change focus when the id is not found", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      bar:select("nonexistent")
      assert.are.equal("yes", bar:get_selection())
    end)


    it("re-renders when auto_render is true and the selection changed", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
        auto_render = true,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select("no")
      assert.is_true(#helpers.get_output() > 0)
    end)


    it("does not re-render when auto_render is true but the selection did not change", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
        auto_render = true,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select("yes")
      assert.are.equal("", helpers.get_output())
    end)

  end)



  describe("select_next()", function()

    it("moves focus to the next button and returns the new selection", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
          {
            id = "cancel",
            label = "Cancel",
          },
        },
        selected = "yes",
      }
      local id = bar:select_next()
      assert.are.equal("no", id)
      assert.are.equal("no", bar:get_selection())
    end)


    it("clamps at the last button without changing focus", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "no",
      }
      local id = bar:select_next()
      assert.are.equal("no", id)
      assert.are.equal("no", bar:get_selection())
    end)


    it("always returns the focused id after the operation", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      local id = bar:select_next()
      assert.are.equal(bar:get_selection(), id)
    end)

  end)



  describe("select_prev()", function()

    it("moves focus to the previous button and returns the new selection", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
          {
            id = "cancel",
            label = "Cancel",
          },
        },
        selected = "no",
      }
      local id = bar:select_prev()
      assert.are.equal("yes", id)
      assert.are.equal("yes", bar:get_selection())
    end)


    it("clamps at the first button without changing focus", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      local id = bar:select_prev()
      assert.are.equal("yes", id)
      assert.are.equal("yes", bar:get_selection())
    end)


    it("always returns the focused id after the operation", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "no",
      }
      local id = bar:select_prev()
      assert.are.equal(bar:get_selection(), id)
    end)

  end)



  describe("select_cancel()", function()

    it("moves focus to the cancel-marked button and returns its id", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
          {
            id = "cancel",
            label = "Cancel",
            cancel = true,
          },
        },
        selected = "yes",
      }
      local id = bar:select_cancel()
      assert.are.equal("cancel", id)
      assert.are.equal("cancel", bar:get_selection())
    end)


    it("returns nil as the second value on success", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "cancel",
            label = "Cancel",
            cancel = true,
          },
        },
        selected = "yes",
      }
      local _, err = bar:select_cancel()
      assert.is_nil(err)
    end)


    it("returns the current selection and 'no cancel button' error when no cancel button is defined", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      local id, err = bar:select_cancel()
      assert.are.equal("yes", id)
      assert.are.equal("no cancel button", err)
    end)


    it("does not change focus when no cancel button is defined", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      bar:select_cancel()
      assert.are.equal("yes", bar:get_selection())
    end)

  end)



  describe("rendering", function()

    it("renders all buttons on a single row", function()
      local bar = ButtonBar {
        items = { { label = "Yes" }, { label = "No" } },
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      local out = utils.strip_ansi(helpers.get_output())

      assert.matches("[Yes] [No]", out, 1, true)
    end)


    it("applies prefix and postfix around each button label", function()
      local bar = ButtonBar {
        items = { { label = "Yes" }, { label = "No" } },
        prefix = "<",
        postfix = ">",
      }

      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      local out = utils.strip_ansi(helpers.get_output())

      assert.matches("<Yes> <No>", out, 1, true)
    end)


    it("renders padding spaces between buttons", function()
      local bar1 = ButtonBar {
        items = { { label = "A" }, { label = "B" } },
        padding = 1,
      }
      bar1:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar1:render()
      assert.matches("[A] [B]", utils.strip_ansi(helpers.get_output()), 1, true)

      local bar3 = ButtonBar {
        items = { { label = "A" }, { label = "B" } },
        padding = 3,
      }
      bar3:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar3:render()
      assert.matches("[A]   [B]", utils.strip_ansi(helpers.get_output()), 1, true)
    end)


    it("applies attr to the full bar background including gaps", function()
      local bar_plain = ButtonBar { items = { { label = "OK" } } }
      bar_plain:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar_plain:render()
      local out_plain = helpers.get_output()

      local bar_attr = ButtonBar {
        items = { { label = "OK" } },
        attr = {
          fg = "white",
          bg = "blue",
        },
      }
      bar_attr:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar_attr:render()
      local out_attr = helpers.get_output()

      assert.are_not.equal(out_plain, out_attr)
    end)


    it("applies button_attr to unselected buttons", function()
      local bar_plain = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      bar_plain:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar_plain:render()
      local out_plain = helpers.get_output()

      local bar_attr = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
        button_attr = { reverse = true },
      }
      bar_attr:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar_attr:render()
      local out_attr = helpers.get_output()

      assert.are_not.equal(out_plain, out_attr)
    end)


    it("applies selected_attr to the focused button", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected_attr = { reverse = true },
      }
      bar:calculate_layout(1, 1, 1, 80)

      bar:select("yes")
      helpers.clear_output()
      bar:render()
      local out_yes = helpers.get_output()

      bar:select("no")
      helpers.clear_output()
      bar:render()
      local out_no = helpers.get_output()

      assert.are_not.equal(out_yes, out_no)
    end)


    it("re-renders after select_next changes focus", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
        auto_render = true,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select_next()
      assert.is_true(#helpers.get_output() > 0)
    end)


    it("re-renders after select_prev changes focus", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "no",
        auto_render = true,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select_prev()
      assert.is_true(#helpers.get_output() > 0)
    end)


    it("re-renders after select_cancel changes focus", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
            cancel = true,
          },
        },
        selected = "yes",
        auto_render = true,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select_cancel()
      assert.is_true(#helpers.get_output() > 0)
    end)


    it("does not render when the panel is hidden", function()
      local bar = ButtonBar { items = { { label = "OK" } } }
      bar:calculate_layout(1, 1, 1, 80)
      bar:hide(true)
      helpers.clear_output()
      bar:render()
      assert.are.equal("", helpers.get_output())
    end)


    it("does not re-render on selection change when auto_render is false", function()
      local bar = ButtonBar {
        items = {
          {
            id = "yes",
            label = "Yes",
          },
          {
            id = "no",
            label = "No",
          },
        },
        selected = "yes",
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:select("no")
      assert.are.equal("", helpers.get_output())
    end)

  end)



  describe("preferred_min_width()", function()

    -- Renders bar at a large fixed width, strips ANSI and surrounding whitespace to
    -- isolate the button content, and measures its display width.
    local function rendered_content_width(bar)
      bar:calculate_layout(1, 1, 1, 999)
      helpers.clear_output()
      bar:render()
      local content = utils.strip_ansi(helpers.get_output()):match("^%s*(.-)%s*$")
      return textwidth.utf8swidth(content)
    end


    it("equals rendered content width for a single button with default options", function()
      local bar = ButtonBar { items = { { label = "Yes" } } }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width for multiple buttons", function()
      local bar = ButtonBar { items = { { label = "Yes" }, { label = "No" } } }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width with a larger custom padding", function()
      local bar = ButtonBar {
        items   = { { label = "Yes" }, { label = "No" } },
        padding = 3,
      }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width when label is shorter than button_min_width", function()
      local bar = ButtonBar {
        items            = { { label = "OK" } },
        button_min_width = 10,
      }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width when label is longer than button_max_width", function()
      local bar = ButtonBar {
        items            = { { label = "Hello World" } },
        button_max_width = 5,
      }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width when button_min_width exceeds button_max_width", function()
      local bar = ButtonBar {
        items            = { { label = "Hello World" } },
        button_min_width = 10,
        button_max_width = 5,
      }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)


    it("equals rendered content width with a custom prefix and postfix", function()
      local bar = ButtonBar {
        items   = { { label = "OK" } },
        prefix  = "<<",
        postfix = ">>",
      }
      assert.are.equal(bar:preferred_min_width(), rendered_content_width(bar))
    end)

  end)



  describe("label sizing", function()

    it("pads a button cell with spaces to reach button_min_width", function()
      local bar = ButtonBar {
        items = { { label = "OK" } },
        button_min_width = 6,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      -- "OK" (2 chars) centered in 6: "  OK  ", wrapped in default brackets
      assert.matches("[  OK  ]", utils.strip_ansi(helpers.get_output()), 1, true)
    end)


    it("truncates a label with an ellipsis when the cell exceeds button_max_width", function()
      local bar = ButtonBar {
        items = { { label = "Hello World" } },
        button_max_width = 5,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      -- "Hello World" truncated to 5 cols: "Hell…", wrapped in default brackets
      assert.matches("[Hell…]", utils.strip_ansi(helpers.get_output()), 1, true)
    end)


    it("applies the same button_min_width and button_max_width to every button", function()
      local bar = ButtonBar {
        items = { { label = "OK" }, { label = "Cancel" } },
        button_min_width = 8,
        button_max_width = 8,
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      local out = utils.strip_ansi(helpers.get_output())
      -- "OK" (2) centered in 8: "   OK   "; "Cancel" (6) centered in 8: " Cancel "
      assert.matches("[   OK   ] [ Cancel ]", out, 1, true)
    end)


    it("renders label at natural width when no button_min_width or button_max_width is set", function()
      local bar = ButtonBar {
        items = { { label = "Hello" }, { label = "World" } },
      }
      bar:calculate_layout(1, 1, 1, 80)
      helpers.clear_output()
      bar:render()
      local out = utils.strip_ansi(helpers.get_output())
      assert.matches("[Hello] [World]", out, 1, true)
    end)

  end)

end)
