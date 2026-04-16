local helpers = require "spec.helpers"


describe("terminal.progress", function()

  local progress
  local t
  local utils
  local width
  local color

  local DEFAULT_STEPSIZE = 10
  local COLORED_SPRITE_CHAR = "█"
  local DONE_MESSAGE_TEXT = "✓ DONE"
  local DONE_MESSAGE_CHAR = " "
  local PLAIN_SPRITE_CHAR = "X"

  setup(function()
    t = helpers.load()
    progress = require "terminal.progress"
    utils = require "terminal.utils"
    width = require "terminal.text.width"
    color = require "terminal.text.color"
  end)


  teardown(function()
    helpers.unload()
  end)


  before_each(function()
    helpers.clear_output()
  end)



  describe("spinner()", function()

    it("uses visible width for colored sprites (ignores ANSI)", function()
      local red_sprite = color.fore_seq("red") .. COLORED_SPRITE_CHAR
      local expected_width = width.utf8swidth(utils.strip_ansi(red_sprite))
      local spinner = progress.spinner({
        sprites = { [0] = "", red_sprite },
        stepsize = DEFAULT_STEPSIZE,
      })

      spinner(false)

      assert.are.equal(red_sprite .. t.cursor.position.left_seq(expected_width), helpers.get_output())
    end)


    it("uses visible width for colored done_sprite", function()
      local done_sprite = color.fore_seq("green") .. DONE_MESSAGE_TEXT
      local done_width = width.utf8swidth(utils.strip_ansi(done_sprite))
      local spinner = progress.spinner({
        sprites = { [0] = "", DONE_MESSAGE_CHAR },
        done_sprite = done_sprite,
        stepsize = DEFAULT_STEPSIZE,
      })

      spinner(true)

      assert.are.equal(done_sprite .. t.cursor.position.left_seq(done_width), helpers.get_output())
    end)


    it("works correctly for plain sprites without ANSI", function()
      local spinner = progress.spinner({
        sprites = { [0] = "", PLAIN_SPRITE_CHAR },
        stepsize = DEFAULT_STEPSIZE,
      })

      spinner(false)

      local sprite_width = width.utf8swidth(PLAIN_SPRITE_CHAR)
      assert.are.equal(
        PLAIN_SPRITE_CHAR .. t.cursor.position.left_seq(sprite_width),
        helpers.get_output()
      )
    end)

  end)

end)
