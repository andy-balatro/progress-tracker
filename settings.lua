-- The "Tracker" tab of the game's settings menu (Options → Settings): linking
-- the game, the code to type or paste on the site, and which profile is sent.
-- Its text follows ProgressTracker.status, which tracker.lua updates every frame.
do
  G.FUNCS.progress_tracker_link = function()
    ProgressTracker.press_link()
  end

  G.FUNCS.progress_tracker_second = function()
    ProgressTracker.press_second()
  end

  local function text_row(field, scale, colour)
    return {
      n = G.UIT.R,
      config = { align = "cm", padding = 0.04 },
      nodes = {
        { n = G.UIT.T, config = { ref_table = ProgressTracker.status, ref_value = field, scale = scale, colour = colour, shadow = true } },
      },
    }
  end

  local function button(field, func, colour)
    return {
      n = G.UIT.C,
      config = { align = "cm", minw = 3.6, minh = 0.7, r = 0.1, colour = colour, hover = true, shadow = true, button = func },
      nodes = {
        { n = G.UIT.T, config = { ref_table = ProgressTracker.status, ref_value = field, scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
      },
    }
  end

  local function settings_tab_contents()
    return {
      n = G.UIT.ROOT,
      config = { align = "cm", padding = 0.1, colour = G.C.CLEAR },
      nodes = {
        text_row("line", 0.45, G.C.UI.TEXT_LIGHT),
        text_row("code", 1.1, G.C.GOLD),
        text_row("hint", 0.36, G.C.UI.TEXT_INACTIVE),
        { n = G.UIT.R, config = { minh = 0.15 } },
        text_row("profile", 0.36, G.C.UI.TEXT_LIGHT),
        text_row("sent", 0.32, G.C.UI.TEXT_INACTIVE),
        {
          n = G.UIT.R,
          config = { align = "cm", padding = 0.15 },
          nodes = {
            button("link_button", "progress_tracker_link", G.C.RED),
            { n = G.UIT.C, config = { minw = 0.2 } },
            button("second_button", "progress_tracker_second", G.C.BLUE),
          },
        },
      },
    }
  end

  -- lovely.toml adds this to the tabs of the game's settings menu.
  function ProgressTracker.settings_tab()
    return { label = "Tracker", tab_definition_function = settings_tab_contents }
  end
end
