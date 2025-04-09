local progress = require("terminal.progress")
local ProgressSpinner = progress.ProgressSpinner

describe("ProgressSpinner", function()
  it("initializes with valid options", function()
    local spinner = ProgressSpinner:new{
      sprites = progress.sprites.spinner,
      stepsize = 0.1,
      textattr = {fg = "blue"},
      done_textattr = {fg = "green"},
      done_sprite = "✔ ",
      row = 5,
      col = 1,
    }
    assert.is_table(spinner)
    assert.are.equal(type(spinner.step_once), "function")
  end)

  it("throws error without sprites", function()
    assert.has_error(function()
      ProgressSpinner:new{}
    end, "sprites must be provided")
  end)

  it("rotates sprite steps", function()
    local spinner = ProgressSpinner:new{
      sprites = { [0] = "-", "|", "/", "\\" },
      stepsize = 0,
    }
    for _ = 1, 5 do
      spinner:step_once()
    end
    spinner:step_once(true) -- done state
  end)
end)
