local helpers = require "spec.helpers"


describe("terminal.cli.confirm", function()

  local Confirm

  setup(function()
    helpers.load()
    Confirm = require("terminal.cli.confirm")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("initializes with defaults", function()
      local d = Confirm{ prompt = "Continue?" }
      assert.are.equal("Continue?", d.prompt)
      assert.are.same(Confirm.sets.ok, d.responses)
      assert.are.equal(Confirm.ids.ok, d.default)
      assert.is_false(d.cancellable)
      assert.is_false(d.clear)
    end)


    it("initializes with all options specified", function()
      local responses = {
        { label = "Yes",    value = "yes" },
        { label = "No",     value = "no" },
        { label = "Cancel", value = "cancel", cancel = true },
      }
      local d = Confirm{
        prompt = "Delete?",
        responses = responses,
        default = Confirm.ids.no,
        cancellable = true,
        clear = true,
      }
      assert.are.equal("Delete?", d.prompt)
      assert.are.same(responses, d.responses)
      assert.are.equal(Confirm.ids.no, d.default)
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


    it("errors when a response entry is missing a label", function()
      assert.has_error(function()
        Confirm{
          prompt = "test",
          responses = { { value = "x" } },
        }
      end, "each response must have a string label")
    end)


    it("errors when default value is not found in responses", function()
      assert.has_error(function()
        Confirm{
          prompt = "test",
          responses = { { label = "OK" } },
          default = "missing",
        }
      end, "default value not found in responses")
    end)


    it("cancellable defaults to true when a response has cancel = true", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.ok_cancel,
      }
      assert.is_true(d.cancellable)
    end)


    it("cancellable can be set true even when no response has cancel = true", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.yes_no,
        cancellable = true,
      }
      assert.is_true(d.cancellable)
    end)


    it("errors when more than one response is marked as cancel", function()
      assert.has_error(function()
        Confirm{
          prompt = "test",
          responses = {
            { label = "A", cancel = true },
            { label = "B", cancel = true },
          },
        }
      end, "only one response can be marked as cancel")
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

    it("returns the value of the default response when Enter pressed", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.ok_cancel,
        default = Confirm.ids.ok,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result, err = d:run()
      assert.are.equal(Confirm.ids.ok, result)
      assert.is_nil(err)
    end)


    it("returns the value after navigating down", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.yes_no,
        default = Confirm.ids.yes,
      }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(helpers.keys.enter)
      local result = d:run()
      assert.are.equal(Confirm.ids.no, result)
    end)


    it("returns the cancel entry value when Esc pressed and a response has cancel = true", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.ok_cancel,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local result = d:run()
      assert.are.equal(Confirm.ids.cancel, result)
    end)


    it("returns nil and 'cancelled' when Esc pressed and no response has cancel = true", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.yes_no,
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local result, err = d:run()
      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)


    it("returns the label as value when value is not specified", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = { { label = "Maybe" } },
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = d:run()
      assert.are.equal("Maybe", result)
    end)


    it("returns arbitrary value types", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = {
          { label = "Yes", value = true },
          { label = "No",  value = false },
        },
        default = false,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = d:run()
      assert.is_false(result)
    end)


    it("can be invoked directly as a function", function()
      local d = Confirm{
        prompt = "Continue?",
        responses = Confirm.sets.yes_no,
        default = Confirm.ids.yes,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = d()
      assert.are.equal(Confirm.ids.yes, result)
    end)

  end)

end)
