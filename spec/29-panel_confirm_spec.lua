local helpers = require "spec.helpers"


describe("terminal.ui.panel.confirm", function()

  local Confirm
  local draw
  local utils

  setup(function()
    helpers.load()
    Confirm = require("terminal.ui.panel.confirm")
    draw    = require("terminal.draw")
    utils   = require("terminal.utils")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("raises error when opts is not a table", function()
      assert.error.matches(function()
        Confirm(nil)
      end, "options must be a table")
    end)


    it("raises error when prompt is missing", function()
      assert.error.matches(function()
        Confirm { buttons = Confirm.sets.ok }
      end, "prompt must be a string or table of strings")
    end)


    it("raises error when prompt is not a string or table", function()
      assert.error.matches(function()
        Confirm {
          prompt  = 42,
          buttons = Confirm.sets.ok,
        }
      end, "prompt must be a string or table of strings")
    end)


    it("raises error when buttons is missing", function()
      assert.error.matches(function()
        Confirm { prompt = "OK?" }
      end, "buttons must be a non%-empty table")
    end)


    it("raises error when buttons is empty", function()
      assert.error.matches(function()
        Confirm {
          prompt  = "OK?",
          buttons = {},
        }
      end, "buttons must be a non%-empty table")
    end)


    describe("cancellable", function()

      it("defaults to true when a cancel-marked button exists", function()
        local dlg = Confirm {
          prompt  = "OK?",
          buttons = Confirm.sets.ok_cancel,
        }
        assert.is_true(dlg.cancellable)
      end)


      it("defaults to false when no cancel-marked button exists", function()
        local dlg = Confirm {
          prompt  = "OK?",
          buttons = Confirm.sets.yes_no,
        }
        assert.is_false(dlg.cancellable)
      end)


      it("can be forced true even without a cancel-marked button", function()
        local dlg = Confirm {
          prompt      = "OK?",
          buttons     = Confirm.sets.yes_no,
          cancellable = true,
        }
        assert.is_true(dlg.cancellable)
      end)


      it("can be forced false even with a cancel-marked button", function()
        local dlg = Confirm {
          prompt      = "OK?",
          buttons     = Confirm.sets.ok_cancel,
          cancellable = false,
        }
        assert.is_false(dlg.cancellable)
      end)

    end)


    describe("without border", function()

      it("dialog has no border; bar and text panel have their fixed borders", function()
        local dlg = Confirm {
          prompt  = "OK?",
          buttons = Confirm.sets.ok,
        }
        assert.is_nil(dlg.border)
        assert.are.equal(draw.box_fmt.blank, dlg._bar.border.format)
        assert.is_not_nil(dlg._text.border)
      end)

    end)


    describe("redraw option", function()

      it("raises an error when redraw is not a function", function()
        assert.error.matches(function()
          Confirm {
            prompt  = "OK?",
            buttons = Confirm.sets.ok,
            redraw  = "not a function",
          }
        end, "redraw must be a function")
      end)


      it("accepts a function without error", function()
        assert.has_no.errors(function()
          Confirm {
            prompt  = "OK?",
            buttons = Confirm.sets.ok,
            redraw  = function() end,
          }
        end)
      end)

    end)


    describe("with border", function()

      local fmt

      before_each(function()
        fmt = draw.box_fmt.rounded:copy()
      end)


      it("border is set on the dialog", function()
        local dlg = Confirm {
          prompt  = "OK?",
          buttons = Confirm.sets.ok,
          border  = { format = fmt },
        }
        assert.are.equal(fmt, dlg.border.format)
      end)


      it("bar and text panel have their fixed borders", function()
        local dlg = Confirm {
          prompt  = "OK?",
          buttons = Confirm.sets.ok,
          border  = { format = fmt },
        }
        assert.are.equal(draw.box_fmt.blank, dlg._bar.border.format)
        assert.is_not_nil(dlg._text.border)
      end)

    end)

  end)



  describe("get_selection()", function()

    before_each(function()
      helpers.set_termsize(25, 80)
    end)


    it("returns the id of the currently focused button", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no,
      }
      assert.are.equal(Confirm.ids.yes, dlg:get_selection())
    end)


    it("reflects button navigation changes", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no,
      }
      dlg:calculate_layout()
      dlg._bar:select_next()
      assert.are.equal(Confirm.ids.no, dlg:get_selection())
    end)

  end)



  describe("calculate_layout()", function()

    before_each(function()
      helpers.set_termsize(25, 80)
    end)


    it("sets dialog width to ButtonBar preferred width plus border overhead", function()
      local dlg_no_border = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
      }
      dlg_no_border:calculate_layout()
      local pref = dlg_no_border._bar:preferred_min_width()
      assert.are.equal(pref, dlg_no_border.width)

      local dlg_with_border = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
        border  = { format = draw.box_fmt.rounded },
      }
      dlg_with_border:calculate_layout()
      assert.are.equal(pref + 2, dlg_with_border.width)
    end)


    it("sets text panel height to the word-wrapped line count of the prompt", function()
      local dlg = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()

      assert.are.equal(1, dlg._text.inner_height)
    end)


    it("centers the dialog horizontally in the terminal", function()
      local dlg = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()

      local expected_col = math.floor((80 - dlg.width) / 2) + 1
      assert.are.equal(expected_col, dlg._text.col)
      assert.are.equal(expected_col, dlg._bar.col)
    end)


    it("centers the dialog vertically in the terminal", function()
      local dlg = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()

      local expected_row = math.floor((25 - dlg.height) / 2) + 1
      assert.are.equal(expected_row, dlg._text.row)
      assert.are.equal(expected_row + dlg._text.height, dlg._bar.row)
    end)


    it("updates correctly when called again after a terminal resize", function()
      local dlg = Confirm {
        prompt  = "?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()
      local col_at_80 = dlg._text.col

      helpers.set_termsize(25, 120)
      dlg:calculate_layout()
      local col_at_120 = dlg._text.col

      assert.are_not.equal(col_at_80, col_at_120)
    end)

  end)



  describe("render()", function()

    before_each(function()
      helpers.set_termsize(25, 80)
    end)


    it("writes the prompt text to the terminal", function()
      local dlg = Confirm {
        prompt  = "Delete this file?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()
      helpers.clear_output()
      dlg:render()

      assert.matches("Delete this file?", utils.strip_ansi(helpers.get_output()), 1, true)
    end)


    it("writes all button labels to the terminal", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no_cancel,
      }
      dlg:calculate_layout()
      helpers.clear_output()
      dlg:render()
      local out = utils.strip_ansi(helpers.get_output())

      assert.matches("[Yes]",    out, 1, true)
      assert.matches("[No]",     out, 1, true)
      assert.matches("[Cancel]", out, 1, true)
    end)


    it("renders top border with title when configured", function()
      local dlg = Confirm {
        prompt  = "Please confirm the action.",
        buttons = Confirm.sets.ok,
        border  = {
          format = draw.box_fmt.rounded,
          title  = "Confirm",
        },
      }
      dlg:calculate_layout()
      helpers.clear_output()
      dlg:render()

      assert.matches("Confirm", utils.strip_ansi(helpers.get_output()), 1, true)
    end)

  end)



  describe("run()", function()

    before_each(function()
      helpers.set_termsize(25, 80)
    end)


    it("returns the id of the focused button when Enter is pressed", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local id = dlg:run()
      assert.are.equal(Confirm.ids.yes, id)
    end)


    it("Right arrow moves focus to the next button", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no,
      }
      helpers.push_kb_input(helpers.keys.right)
      helpers.push_kb_input(helpers.keys.enter)
      local id = dlg:run()
      assert.are.equal(Confirm.ids.no, id)
    end)


    it("Left arrow moves focus to the previous button", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons  = Confirm.sets.yes_no_cancel,
        default  = Confirm.ids.no,
      }
      helpers.push_kb_input(helpers.keys.left)
      helpers.push_kb_input(helpers.keys.enter)
      local id = dlg:run()
      assert.are.equal(Confirm.ids.yes, id)
    end)


    it("returns the cancel button id when ESC is pressed and a cancel button exists", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.ok_cancel,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local id, err = dlg:run()
      assert.are.equal(Confirm.ids.cancel, id)
      assert.is_nil(err)
    end)


    it("returns nil and 'cancelled' when ESC is pressed with no cancel button and cancellable is true", function()
      local dlg = Confirm {
        prompt      = "OK?",
        buttons     = Confirm.sets.yes_no,
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local id, err = dlg:run()
      assert.is_nil(id)
      assert.are.equal("cancelled", err)
    end)


    it("ignores ESC when cancellable is false", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.yes_no,
      }
      helpers.push_kb_input(helpers.keys.esc)
      helpers.push_kb_input(helpers.keys.enter)
      local id = dlg:run()
      assert.are.equal(Confirm.ids.yes, id)
    end)


    it("Ctrl+C behaves like ESC", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.ok_cancel,
      }
      helpers.push_kb_input(helpers.keys.ctrl_c)
      local id = dlg:run()
      assert.are.equal(Confirm.ids.cancel, id)
    end)


    it("calls redraw on exit", function()
      local exit_calls = 0
      local render_calls = 0
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.ok,
        redraw  = function()
          -- count calls after render has happened (render_calls already incremented)
          if render_calls > 0 then exit_calls = exit_calls + 1 end
        end,
      }
      -- spy on render
      local orig_render = dlg.render
      dlg.render = function(self)
        render_calls = render_calls + 1
        return orig_render(self)
      end

      helpers.push_kb_input(helpers.keys.enter)
      dlg:run()
      assert.are.equal(1, exit_calls)
    end)


    it("run() works without a redraw callback", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.ok,
      }
      helpers.push_kb_input(helpers.keys.enter)
      assert.has_no.errors(function() dlg:run() end)
    end)


    it("re-renders after a terminal resize", function()
      local dlg = Confirm {
        prompt  = "OK?",
        buttons = Confirm.sets.ok,
      }
      dlg:calculate_layout()
      local col_at_80 = dlg._text.col
      dlg._last_screen_h = 25
      dlg._last_screen_w = 80

      helpers.set_termsize(25, 120)
      helpers.push_kb_input(helpers.keys.enter)
      dlg:run()

      assert.are_not.equal(col_at_80, dlg._text.col)
    end)

  end)

end)
