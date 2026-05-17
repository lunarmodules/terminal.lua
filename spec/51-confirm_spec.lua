local helpers = require "spec.helpers"


describe("terminal.cli.confirm", function()

  local Confirm, utils

  setup(function()
    helpers.load()
    Confirm = require("terminal.cli.confirm")
    utils = require("terminal.utils")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("initializes with defaults", function()
      local d = Confirm{ prompt = "Continue?" }
      assert.are.equal("Continue?", d.prompt)
      assert.are.same({ "ok" }, d.responses)
      assert.are.equal("ok", d.default)
      assert.is_false(d.cancellable)
      assert.is_false(d.clear)
    end)


    it("initializes with all options specified", function()
      local d = Confirm{
        prompt = "Delete?",
        responses = utils.response_sets.yes_no_cancel,
        default = utils.response_ids.no,
        cancellable = true,
        clear = true,
      }
      assert.are.equal("Delete?", d.prompt)
      assert.are.same({ "yes", "no", "cancel" }, d.responses)
      assert.are.equal("no", d.default)
      assert.is_true(d.cancellable)
      assert.is_true(d.clear)
    end)


    it("errors when opts is not a table", function()
      assert.has_error(function()
        Confirm("not a table")
      end, "options must be a table")
    end)


    it("errors when prompt is not a string", function()
      assert.has_error(function()
        Confirm{ prompt = 42 }
      end, "prompt must be a string")
    end)


    it("errors when responses contains an invalid id", function()
      assert.has_error(function()
        Confirm{ prompt = "test", responses = { "maybe" } }
      end, 'Invalid response id: "maybe". Expected one of: "abort", "cancel", "continue", "ignore", "no", "ok", "retry", "try_again", "yes"')
    end)


    it("errors when default is not a valid response id", function()
      assert.has_error(function()
        Confirm{ prompt = "test", default = "maybe" }
      end, 'Invalid response id: "maybe". Expected one of: "abort", "cancel", "continue", "ignore", "no", "ok", "retry", "try_again", "yes"')
    end)


    it("errors when default is not in the responses list", function()
      assert.has_error(function()
        Confirm{
          prompt = "test",
          responses = utils.response_sets.yes_no,
          default = utils.response_ids.cancel,
        }
      end, "default 'cancel' is not a valid response")
    end)

  end)



  describe("height()", function()

    it("returns a positive number", function()
      local d = Confirm{ prompt = "Continue?" }
      local h = d:height()
      assert.is_number(h)
      assert.is_true(h > 0)
    end)


    it("matches the height of the internal Select widget", function()
      local d = Confirm{ prompt = "Continue?" }
      assert.are.equal(d._select:height(), d:height())
    end)

  end)



  describe("run()", function()

    it("returns the default response id when Enter pressed", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = utils.response_sets.ok_cancel,
        default = utils.response_ids.ok,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result, err = d:run()
      assert.are.equal("ok", result)
      assert.is_nil(err)
    end)


    it("returns the response id after navigating down", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = utils.response_sets.yes_no,
        default = utils.response_ids.yes,
      }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(helpers.keys.enter)
      local result = d:run()
      assert.are.equal("no", result)
    end)


    it("returns nil and 'cancelled' when Esc pressed with cancellable=true", function()
      local d = Confirm{
        prompt = "Continue?",
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local result, err = d:run()
      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)


    it("can be invoked directly as a function", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = utils.response_sets.yes_no,
        default = utils.response_ids.yes,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = d()
      assert.are.equal("yes", result)
    end)

  end)

end)
