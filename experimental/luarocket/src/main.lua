local TextPanel = require("terminal.ui.panel.text")
local luarocks = require("luarocket.luarocks")
local terminal = require("terminal")
local keymap = require("terminal.input.keymap").default_key_map
local Screen = require("terminal.ui.panel.screen")
local Panel = require("terminal.ui.panel")
local copas = require("copas")
local keys = require("terminal.input.keymap").default_keys
local Bar = require("terminal.ui.panel.bar")



local active_panel = nil



local screen = Screen {
  header = Bar {
    name = "header",
    -- left = {
    --   text = "TextPanel Example",
    --   attr = { fg = "cyan", brightness = "bright" }
    -- },
    center = {
      text = "LuaRocket 🚀",
      attr = { fg = "yellow", brightness = "bright" }
    },
    -- right = {
    --   text = "Press 'q' to quit",
    --   attr = { fg = "green", brightness = "bright" }
    -- },
    attr = { bg = "blue" },
    auto_render = true,
  },

  body = Panel {
    name = "screen_body",
    orientation = Panel.orientations.vertical,
    split_ratio = 0.7,
    children = {
      -- top panel is where we have the interactive panels
      Panel {
        name = "content_body",
        orientation = Panel.orientations.horizontal,
        split_ratio = 0.5,
        children = {
          TextPanel {
            name = "rockstree",
            lines = {"contents of rockstree"},
            -- line_formatter = TextPanel.format_line_wordwrap,
            scroll_step = 1,
            text_attr = { fg = "cyan", brightness = "bright" },
            border = {
              title = "Rockstree",
              format = terminal.draw.box_fmt.single,
            },
            auto_render = true,
          },
          TextPanel {
            name = "config",
            lines = {"luarocks config"},
            border = {
              title = "LR Config",
              format = terminal.draw.box_fmt.single,
            },
            auto_render = true,
          },
        },
      },
      -- bottom panel is for luarocks log output
      TextPanel {
        name = "command_log",
        lines = {"waiting for LuaRocks command..."},
        line_formatter = TextPanel.format_line_wrap,
        scroll_step = 1,
        text_attr = { fg = "cyan", brightness = "bright" },
        border = {
          title = "Luarocks logs",
          format = terminal.draw.box_fmt.single_top,
        },
        auto_render = true,
        max_lines = 300,  -- keep last 300 lines of log output
      },
    },
  },

  footer = Bar {
    name = "footer",
    left = {
      text = "left text",
      attr = { fg = "magenta", brightness = "bright" }
    },
    center = {
      text = "middle text",
      attr = { fg = "yellow", brightness = "bright" }
    },
    right = {
      text = "q: quit",
      attr = { fg = "red", brightness = "bright" }
    },
    attr = { bg = "black", fg = "white" },
    auto_render = true,
  }
}


-- Table providing key-handler function on a per-panel basis.
-- looking up the current selected panel, to call the corresponding handler function.
-- Each handler takes the key+keytype from input.readansi() results as arguments.
-- They should return truthy if the key needs further handling, falsey otherwise.
local keyhandlers = setmetatable({

  [screen.panels.rockstree] = function(rawkey, keyname, ktype)
    local panel = screen.panels.rockstree

    if keyname == keys.up then
      panel:set_highlight((panel:get_highlight() or 0) - 1, true)

    elseif keyname == keys.down then
      panel:set_highlight((panel:get_highlight() or 0) + 1, true)

    elseif keyname == keys.pageup then
      panel:page_up()

    elseif keyname == keys.pagedown then
      panel:page_down()

    else
      return true -- report unhandled key
    end
  end,



  [screen.panels.command_log] = function(rawkey, keyname, ktype)
    local panel = screen.panels.command_log

    if keyname == keys.up then
      panel:scroll_up()

    elseif keyname == keys.down then
      panel:scroll_down()

    elseif keyname == keys.pageup then
      panel:page_up()

    elseif keyname == keys.pagedown then
      panel:page_down()

    else
      return true -- report unhandled key
    end
  end,



  [screen.panels.config] = function(rawkey, keyname, ktype)
    local panel = screen.panels.config

    if keyname == keys.up then
      panel:scroll_up()

    elseif keyname == keys.down then
      panel:scroll_down()

    elseif keyname == keys.pageup then
      panel:page_up()

    elseif keyname == keys.pagedown then
      panel:page_down()

    else
      return true -- report unhandled key
    end
  end,



}, {
  __index = function(self, key)
    error("No key-handler found for panel: " .. tostring(key), 2)
  end
})



local tab_select do

  -- The TAB order to switch between panels
  local tab_order = {
    [screen.panels.rockstree] = 1,
    [screen.panels.config] = 2,
    [screen.panels.command_log] = 3,
  }
  local tab_count = 0
  for _, _ in pairs(tab_order) do
    tab_count = tab_count + 1
  end

  -- select another tab in the tab order.
  -- `delta` can be 0 to reconfirm the current panel.
  -- @param delta the number of tabs to switch, positive to switch forward, negative to switch backward
  function tab_select(delta)
    local target = active_panel and (tab_order[active_panel] + delta) or 1
    while target < 1 do
      target = tab_count + target
    end
    while target > tab_count do
      target = target - tab_count
    end

    local new_active_panel
    for panel, order in pairs(tab_order) do
      if order == target then
        new_active_panel = panel
        break
      end
    end

    if not new_active_panel:visible() then
      -- selected panel is not visible, so move one more in the same direction,
      -- and recurse to try again.

      -- if delta is too high/low, we're in a loop, so bail out.
      if delta > tab_count or delta < -tab_count then
        error("there are no more visible panels to select", 2)
      end

      if delta >= 0 then -- MUST cater for the 0 case !
        return tab_select(delta + 1)
      else
        return tab_select(delta - 1)
      end
    end

    if new_active_panel == active_panel then
      return -- no change, so don't do anything
    end

    -- unreverse the current tab title.
    if active_panel then
      local attr = active_panel.border.title_attr
      if not attr then
        attr = { reverse = false }
        active_panel.border.title_attr = attr
      else
        attr.reverse = false
      end
      active_panel:draw_border()
    end

    -- reverse the newly selected tab title.
    local attr = new_active_panel.border.title_attr
    if not attr then
      attr = { reverse = true }
      new_active_panel.border.title_attr = attr
    else
      attr.reverse = true
    end
    new_active_panel:draw_border()

    active_panel = new_active_panel
  end
end



local core_keyhandler do

  -- toggle the visibility of the log panel
  local function toggle_log_panel()
    local log_panel = screen.panels.command_log
    log_panel:hide(log_panel:visible())
    tab_select(0)  -- reselect current panel to ensure valid selection
    screen:calculate_layout()
    screen:render()
  end


  -- toggle the visibility of the config panel
  local function toggle_config_panel()
    local config_panel = screen.panels.config
    config_panel:hide(config_panel:visible())
    tab_select(0)  -- reselect current panel to ensure valid selection
    screen:calculate_layout()
    screen:render()
  end



  -- will be called if the key received wasn't handled by the panel specific keyhandler.
  core_keyhandler = function(rawkey, keyname, ktype)
    if rawkey == "l" then
      toggle_log_panel()

    elseif rawkey == "c" then
      toggle_config_panel()

    elseif rawkey == "q" then
      copas.exit()  -- exit the application

    elseif keyname == keys.tab then
      tab_select(1)  -- select next panel

    elseif keyname == keys.shift_tab then
      tab_select(-1)  -- select previous panel

    else
      return true
    end
  end
end



local function main()

  luarocks.set_logpanel(screen.panels.command_log)
  luarocks.set_configpanel(screen.panels.config)
  luarocks.set_listpanel(screen.panels.rockstree)

  screen:calculate_layout()
  screen:render()
  terminal.cursor.visible.stack.push(false)

  tab_select(0)  -- select the first panel by default
  luarocks.test_luarocks()
  luarocks.get_config()
  luarocks.list_rocks()


  while not copas.exiting() do
    local rawkey, ktype = terminal.input.readansi(0.1)
    local keyname = keymap[rawkey]

    -- first handle key by the panel-specific key-handler
    if keyhandlers[active_panel](rawkey, keyname, ktype) then
      -- Key remained unhandled, call generic key-handler
-- if key then print("key:", rawkey, "ktype:", ktype) end
      core_keyhandler(rawkey, keyname, ktype)
    end

    screen:check_resize(true)
  end
end



return main
