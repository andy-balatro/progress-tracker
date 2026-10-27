-- Andy's Progress Tracker: sends a Balatro profile's progress to
-- bot.andy-balatro.com, for the streamer's public page and chat commands.
-- Linking the game and talking to the site is andys_link.lua's, shared with
-- Andy's Chat, so one link does both.

-- Wrapped in do ... end, like the other files, since lovely.toml appends
-- them all to the game's main.lua, whose locals are limited.
do
  local CONFIG_FILE = "config/progress-tracker.jkr"

  ProgressTracker = {}

  -- Saved settings ------------------------------------------------------------

  -- { profile = the profile slot whose progress is sent }
  local function load_config()
    local ok, saved = pcall(function()
      local file = love.filesystem.read(CONFIG_FILE)
      return file and STR_UNPACK(file)
    end)
    return ok and type(saved) == "table" and saved or {}
  end

  function ProgressTracker.save_config()
    if not love.filesystem.getInfo("config") then love.filesystem.createDirectory("config") end
    love.filesystem.write(CONFIG_FILE, STR_PACK(ProgressTracker.config))
  end

  ProgressTracker.config = load_config()

  -- What the settings tab shows. Its text nodes follow these fields.
  ProgressTracker.status = {
    line = "", code = "", hint = "", profile = "", sent = "",
    link_button = "Link", second_button = "Track this profile",
  }

  -- The profile the game is linked on is the one sent, until another is picked.
  AndysLink.on_change(function(linked)
    if linked then
      ProgressTracker.config.profile = G.SETTINGS.profile
      ProgressTracker.save_config()
      ProgressTracker.progress_changed()
    else
      ProgressTracker.status.sent = ""
    end
  end)

  function ProgressTracker.press_link()
    AndysLink.press_link()
  end

  -- The second button copies the code while one shows, so it can be pasted on
  -- the site, and otherwise sends this profile's progress from now on.
  function ProgressTracker.press_second()
    if AndysLink.showing_code() then
      AndysLink.copy_code()
      return
    end
    ProgressTracker.config.profile = G.SETTINGS.profile
    ProgressTracker.save_config()
    ProgressTracker.progress_changed()
  end

  -- Every frame ---------------------------------------------------------------

  local function profile_name(slot)
    local profile = slot and G.PROFILES and G.PROFILES[slot]
    return profile and profile.name or ("Profile " .. tostring(slot))
  end

  local function update_status()
    local status, link = ProgressTracker.status, AndysLink.status
    status.line, status.code, status.hint, status.link_button = link.line, link.code, link.hint, link.link_button
    if AndysLink.is_linked() and not AndysLink.showing_code() then
      status.hint = AndysLink.host .. "/tracker/" .. tostring(AndysLink.login())
    end
    local tracked = ProgressTracker.config.profile
    status.profile = tracked and ("Sending progress from: " .. profile_name(tracked)) or ""
    if AndysLink.showing_code() then
      status.second_button = AndysLink.just_copied() and "Copied!" or "Copy code"
    else
      status.second_button = tracked == G.SETTINGS.profile and "Tracking this profile" or "Track this profile"
    end
  end

  local update_ref = Game.update
  function Game:update(dt)
    update_ref(self, dt)
    if ProgressTracker.send_progress then ProgressTracker.send_progress(love.timer.getTime()) end
    update_status()
  end
end
