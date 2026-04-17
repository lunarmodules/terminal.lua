local helpers = require "spec.helpers"


describe("terminal.ui.canvas", function()

  local Canvas

  setup(function()
    helpers.load()
    Canvas = require("terminal.ui.canvas")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    pending("creates a canvas with valid width and height", function() end)

    pending("raises an error when width is missing", function() end)

    pending("raises an error when height is missing", function() end)

    pending("raises an error when width is not positive", function() end)

    pending("raises an error when height is not positive", function() end)

    pending("exposes pixel dimensions as 2x width and 4x height", function() end)

    pending("defaults to blank (all-dots-off) cells", function() end)

    pending("uses filled (all-dots-on) cells when invert option is set", function() end)

  end)



  describe("set()", function()

    pending("illuminates a pixel", function() end)

    pending("on an already-set pixel is idempotent", function() end)

    pending("handles the top-left corner pixel (0, 0)", function() end)

    pending("handles the bottom-right corner pixel", function() end)

    pending("affects only the correct braille cell", function() end)

  end)



  describe("unset()", function()

    pending("extinguishes a pixel", function() end)

    pending("on an already-unset pixel is idempotent", function() end)

    pending("in the same cell as set() is independent per dot", function() end)

  end)



  describe("clear()", function()

    pending("resets all cells to blank after pixels were set", function() end)

    pending("respects the invert option when clearing", function() end)

  end)



  describe("render()", function()

    pending("returns a string", function() end)

    pending("a freshly created canvas renders all blank cells", function() end)

    pending("a fully set canvas renders all filled cells", function() end)

    pending("cursor ends at the top-left of the canvas after render", function() end)

    pending("render reflects set pixels correctly", function() end)

    pending("render reflects unset pixels correctly", function() end)

  end)



  describe("get_pixels()", function()

    pending("returns pixel width and height matching 2*cols and 4*rows", function() end)

  end)



  describe("get_size()", function()

    pending("returns rows and columns matching the init options", function() end)

  end)



  describe("drawing", function()

    describe("line()", function()

      pending("draws a horizontal line", function() end)

      pending("draws a vertical line", function() end)

      pending("draws a diagonal line", function() end)

      pending("draws a single-pixel line (x1==x2, y1==y2)", function() end)

      pending("clears pixels when the clear flag is set", function() end)

    end)



    describe("circle()", function()

      pending("draws a circle outline", function() end)

      pending("fills a circle when fill is true", function() end)

      pending("clears pixels when the clear flag is set", function() end)

      pending("handles radius zero (single pixel)", function() end)

    end)



    describe("polygon()", function()

      pending("draws nothing for an empty points table", function() end)

      pending("draws a single dot for one point", function() end)

      pending("draws a line for two points", function() end)

      pending("draws a closed triangle outline for three points", function() end)

      pending("fills a polygon when fill is true", function() end)

      pending("clears pixels when the clear flag is set", function() end)

    end)

  end)

end)
