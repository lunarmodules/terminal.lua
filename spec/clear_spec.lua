local clear = require "terminal.clear"


describe("Clear Module Tests", function()


    it("should return correct ANSI sequence for clearing entire screen", function()
        assert.are.equal("\27[2J", clear.clears())
    end)


    it("should return correct ANSI sequence for clearing line", function()
        assert.are.equal("\27[2K", clear.clear_lines())
    end)


    it("should return correct ANSI sequence for clearing line start", function()
        assert.are.equal("\27[1K", clear.clear_starts())
    end)


    it("should return correct ANSI sequence for clearing line end", function()
        assert.are.equal("\27[0K", clear.clear_ends())
    end)


    it("should return correct ANSI sequence for clearing top of screen", function()
        assert.are.equal("\27[1J", clear.clear_tops())
    end)


    it("should return correct ANSI sequence for clearing bottom of screen", function()
        assert.are.equal("\27[0J", clear.clear_bottoms())
    end)

end)
