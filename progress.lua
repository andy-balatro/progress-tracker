-- The tracked profile's progress, sent to the server whenever it changes:
-- every joker's best stake sticker, every deck's best stake, the challenges
-- won, the achievements (achievements.lua) and the collection, counted the
-- way the game's Profile → Progress screen does.
do
  local CHECK_SECONDS = 5
  -- After a failed request, so a server that's down isn't asked every 5 seconds.
  local RETRY_SECONDS = 30

  local next_check = 0
  local sending = false
  -- What the server has, so only changes are sent.
  local last_sent = nil
  local last_sent_at = nil
  -- Why the last send failed, shown until one works.
  local failure = nil

  -- How far a joker or deck is: "L" locked, "U" undiscovered (jokers), or the
  -- highest stake won with it (0 for none yet).
  local function joker_standing(center)
    if not center.unlocked then return "L" end
    if not center.discovered then return "U" end
    return get_joker_win_sticker(center, true)
  end

  local function deck_standing(center)
    if not center.unlocked then return "L" end
    return get_deck_win_stake(center.key)
  end

  -- The fields the server's /api/game/progress takes, or nil before
  -- the profile has loaded.
  local function current_progress()
    local profile = G.PROFILES[G.SETTINGS.profile]
    local collection = G.DISCOVER_TALLIES and G.DISCOVER_TALLIES.total
    if not (profile and collection and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker) then return nil end

    local jokers = {}
    for _, center in ipairs(G.P_CENTER_POOLS.Joker) do
      jokers[#jokers + 1] = center.key .. "=" .. joker_standing(center)
    end

    local decks = {}
    for _, center in ipairs(G.P_CENTER_POOLS.Back) do
      if not center.omit then decks[#decks + 1] = center.key .. "=" .. deck_standing(center) end
    end

    local challenges = {}
    for _, challenge in ipairs(G.CHALLENGES) do
      if profile.challenge_progress.completed[challenge.id] then challenges[#challenges + 1] = challenge.id end
    end

    if not G.ACHIEVEMENTS then fetch_achievements() end
    local achievements = {}
    local earned = ProgressTracker.earned_achievements()
    for name in pairs(G.ACHIEVEMENTS) do
      if earned[name] then achievements[#achievements + 1] = name end
    end
    table.sort(achievements)

    return {
      profile = profile.name or tostring(G.SETTINGS.profile),
      jokers = table.concat(jokers, ","),
      decks = table.concat(decks, ","),
      challenges = table.concat(challenges, ","),
      achievements = table.concat(achievements, ","),
      collection_tally = collection.tally,
      collection_of = collection.of,
    }
  end

  -- Sends everything again on the next check, e.g. after linking.
  function ProgressTracker.progress_changed()
    last_sent = nil
    next_check = 0
  end

  local function ago(seconds)
    if seconds < 60 then return "just now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
    return math.floor(seconds / 3600) .. "h ago"
  end

  -- Called every frame by tracker.lua.
  function ProgressTracker.send_progress(now)
    local status = ProgressTracker.status
    if failure then status.sent = failure
    elseif last_sent_at then status.sent = "Last sent " .. ago(now - last_sent_at) end
    if sending or now < next_check or not AndysLink.is_linked() then return end
    next_check = now + CHECK_SECONDS
    -- Other profiles (a casual one, say) don't touch the page.
    if G.SETTINGS.profile ~= ProgressTracker.config.profile then
      status.sent = "Not sending: this isn't the tracked profile"
      return
    end

    local progress = current_progress()
    if not progress then return end
    local fingerprint = table.concat({ progress.profile, progress.jokers, progress.decks, progress.challenges,
      progress.achievements, progress.collection_tally, progress.collection_of }, "|")
    if fingerprint == last_sent then return end

    sending = true
    AndysLink.post("/api/game/progress", progress, function(code, body)
      sending = false
      failure = nil
      if code == 200 then
        last_sent, last_sent_at = fingerprint, love.timer.getTime()
      elseif code == 401 then
        -- Unlinked on the site; AndysLink drops the link and says so.
        last_sent_at = nil
        status.sent = ""
      elseif code == 429 then
        -- Sent too soon after the last one: try again on the next check.
      else
        next_check = love.timer.getTime() + RETRY_SECONDS
        failure = "Couldn't send" .. (code ~= 0 and " (" .. code .. ")" or "") .. ", retrying"
        print("[progress-tracker] upload failed: " .. tostring(code) .. " " .. tostring(body))
      end
    end)
  end
end
