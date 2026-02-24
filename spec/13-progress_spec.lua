local helpers = require "spec.helpers"


describe("terminal.progress", function()

  local terminal
  local progress

  setup(function()
    terminal = helpers.load()
    progress = require("terminal.progress")
  end)


  teardown(function()
    progress = nil
    terminal = nil
    helpers.unload()
  end)



  describe("spinner()", function()

    before_each(function()
      helpers.clear_output()
    end)



    it("uses visible width for ANSI-styled single-width sprites", function()
      local spinner = progress.spinner({
        sprites = {
          [0] = "",
          "\27[31mX\27[0m",
        },
        stepsize = 10,
      })

      spinner(false)

      assert.are.equal(
        "\27[31mX\27[0m" .. terminal.cursor.position.left_seq(1),
        helpers.get_output()
      )
    end)


    it("uses visible width for ANSI-styled double-width sprites", function()
      local spinner = progress.spinner({
        sprites = {
          [0] = "",
          "\27[31m界\27[0m",
        },
        stepsize = 10,
      })

      spinner(false)

      assert.are.equal(
        "\27[31m界\27[0m" .. terminal.cursor.position.left_seq(2),
        helpers.get_output()
      )
    end)


    it("uses visible width for ANSI-styled done_sprite", function()
      local spinner = progress.spinner({
        sprites = {
          [0] = "x",
          "x",
        },
        done_sprite = "\27[32mOK\27[0m",
        stepsize = 10,
      })

      spinner(true)

      assert.are.equal(
        "\27[32mOK\27[0m" .. terminal.cursor.position.left_seq(2),
        helpers.get_output()
      )
    end)

  end)

end)