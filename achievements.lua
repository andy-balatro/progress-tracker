-- Achievements, kept per profile. The game's are Steam's, so ones earned
-- before are already done on a fresh profile, and Ankh turns them off anyway.
-- The game still checks for them, so each one earned is kept in the profile
-- itself and saved with the rest of it in profile.jkr. Only what's earned
-- with the mod installed counts.
do
  function ProgressTracker.earned_achievements()
    local profile = G.PROFILES[G.SETTINGS.profile]
    profile.progress_tracker_achievements = profile.progress_tracker_achievements or {}
    return profile.progress_tracker_achievements
  end

  -- The game's own "Achievement Unlocked!" popup on the right, which it only
  -- shows for achievements new to Steam, never with Ankh. Only on the profile
  -- being sent, since older profiles would pop up achievements earned long
  -- ago. Like the game, it waits for the hand being scored to finish.
  local function show_unlocked(name)
    if G.SETTINGS.profile ~= ProgressTracker.config.profile then return end
    if not G.ACHIEVEMENTS then fetch_achievements() end
    local game_shows_it = not G.F_NO_ACHIEVEMENTS and G.ACHIEVEMENTS[name] and not G.ACHIEVEMENTS[name].earned
    if game_shows_it then return end
    G.E_MANAGER:add_event(Event({
      no_delete = true,
      blockable = false,
      blocking = false,
      func = function()
        if G.STATE == G.STATES.HAND_PLAYED then return false end
        notify_alert(name)
        return true
      end,
    }), "achievement")
  end

  local unlock_achievement_ref = unlock_achievement
  function unlock_achievement(name, ...)
    -- Like the game, profiles with everything unlocked don't earn any.
    local profile = G.PROFILES[G.SETTINGS.profile]
    if profile and not profile.all_unlocked then
      local earned = ProgressTracker.earned_achievements()
      if not earned[name] then
        earned[name] = true
        G:save_progress()
        show_unlocked(name)
      end
    end
    return unlock_achievement_ref(name, ...)
  end
end
