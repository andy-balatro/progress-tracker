-- Andy's Progress Tracker: sends a Balatro profile's progress to
-- bot.andy-balatro.com, for the streamer's public page and chat command.
-- Requests go over HTTPS, with the "https" module Balatro ships, on a
-- background thread so the game never waits on the network.

-- Wrapped in do ... end, like the other files, since lovely.toml appends
-- them all to the game's main.lua, whose locals are limited.
do
  -- Set PROGRESS_TRACKER_URL to try the mod against another server.
  local SERVER = os.getenv("PROGRESS_TRACKER_URL") or "https://bot.andy-balatro.com"
  local CONFIG_FILE = "config/progress-tracker.jkr"

  ProgressTracker = { server = SERVER }

  -- Saved settings ------------------------------------------------------------

  -- { token = upload token, login = Twitch login it's linked to,
  --   profile = the profile slot whose progress is sent }
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

  -- JSON ----------------------------------------------------------------------

  local function json_string(s)
    local escaped = tostring(s):gsub('[%c"\\]', function(c)
      return string.format("\\u%04x", c:byte())
    end)
    return '"' .. escaped .. '"'
  end

  -- Flat tables of strings, numbers and booleans are all requests need.
  function ProgressTracker.encode(fields)
    local parts = {}
    for key, value in pairs(fields) do
      local kind = type(value)
      local encoded = (kind == "number" or kind == "boolean") and tostring(value) or json_string(value)
      parts[#parts + 1] = json_string(key) .. ":" .. encoded
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end

  -- The server's answers are small flat objects, so matching beats a parser.
  -- Only for values without quotes or escapes, which is all it sends back.
  function ProgressTracker.field(body, name)
    return type(body) == "string" and body:match('"' .. name .. '":"([^"\\]*)"') or nil
  end

  -- Network -------------------------------------------------------------------

  local NETWORK_THREAD = [==[
  local has_https, https = pcall(require, "https")
  local requests = love.thread.getChannel("progress_tracker_requests")
  local responses = love.thread.getChannel("progress_tracker_responses")

  while true do
    local request = requests:demand()
    local code, body
    if has_https then
      local headers = { ["Content-Type"] = "application/json", ["User-Agent"] = "progress-tracker" }
      if request.token then headers["Authorization"] = "Bearer " .. request.token end
      local ok, c, b = pcall(https.request, request.url, { method = "POST", headers = headers, data = request.body })
      if ok then code, body = c, b else code, body = 0, tostring(c) end
    else
      code, body = 0, "no https module: " .. tostring(https)
    end
    responses:push({ id = request.id, code = code or 0, body = body or "" })
  end
  ]==]

  local requests = love.thread.getChannel("progress_tracker_requests")
  local responses = love.thread.getChannel("progress_tracker_responses")
  -- Kept referenced so the thread is never garbage collected.
  ProgressTracker.thread = love.thread.newThread(NETWORK_THREAD)
  ProgressTracker.thread:start()

  local callbacks, next_id = {}, 1

  -- POSTs `fields` as JSON to `path` on the server, then calls
  -- on_done(code, body) from the game's update. code is 0 when the request
  -- didn't get an answer at all.
  function ProgressTracker.post(path, fields, token, on_done)
    local id = next_id
    next_id = next_id + 1
    callbacks[id] = on_done
    requests:push({ id = id, url = SERVER .. path, body = ProgressTracker.encode(fields or {}), token = token })
  end

  local function receive()
    while true do
      local response = responses:pop()
      if not response then return end
      local on_done = callbacks[response.id]
      callbacks[response.id] = nil
      if on_done then on_done(response.code, response.body) end
    end
  end

  -- What the settings tab shows. Its text nodes follow these fields.
  ProgressTracker.status = {
    line = "", code = "", hint = "", profile = "", sent = "",
    link_button = "Link", track_button = "Track this profile",
  }

  -- Linking ---------------------------------------------------------------------

  -- Like a TV app's sign-in: the server hands out a code, the streamer types it
  -- on the site, and asking every few seconds gets the upload token once they have.
  local LINK_POLL_SECONDS = 3
  -- { code, secret, url, next_poll, waiting } while a code is showing.
  local link = nil

  function ProgressTracker.is_linked()
    return ProgressTracker.config.token ~= nil
  end

  function ProgressTracker.linking()
    return link ~= nil
  end

  function ProgressTracker.start_link()
    if link and link.waiting then return end
    link = { waiting = true }
    ProgressTracker.status.line = "Asking for a code..."
    ProgressTracker.post("/api/tracker/game/link", {}, nil, function(code, body)
      local link_code, secret = ProgressTracker.field(body, "code"), ProgressTracker.field(body, "secret")
      if code ~= 200 or not link_code or not secret then
        link = nil
        ProgressTracker.status.line = "Couldn't reach the tracker" .. (code ~= 0 and " (" .. code .. ")" or "")
        print("[progress-tracker] link failed: " .. tostring(code) .. " " .. tostring(body))
        return
      end
      link = {
        code = link_code,
        secret = secret,
        url = ProgressTracker.field(body, "url") or (SERVER .. "/tracker/link-game"),
        next_poll = love.timer.getTime() + LINK_POLL_SECONDS,
      }
    end)
  end

  function ProgressTracker.press_link()
    if link and link.code then ProgressTracker.open_link_page() else ProgressTracker.start_link() end
  end

  function ProgressTracker.track_this_profile()
    ProgressTracker.config.profile = G.SETTINGS.profile
    ProgressTracker.save_config()
    ProgressTracker.progress_changed()
  end

  -- The page to type the code on, with the code filled in.
  function ProgressTracker.open_link_page()
    if link and link.code then love.system.openURL(link.url .. "?code=" .. link.code) end
  end

  local function poll_link(now)
    if not link or link.waiting or not link.secret or now < link.next_poll then return end
    link.waiting = true
    ProgressTracker.post("/api/tracker/game/link-status", { secret = link.secret }, nil, function(code, body)
      if not link then return end
      link.waiting = false
      link.next_poll = love.timer.getTime() + LINK_POLL_SECONDS
      local status = ProgressTracker.field(body, "status")
      if code == 200 and status == "linked" then
        ProgressTracker.config.token = ProgressTracker.field(body, "token")
        ProgressTracker.config.login = ProgressTracker.field(body, "login")
        ProgressTracker.config.profile = G.SETTINGS.profile
        ProgressTracker.save_config()
        ProgressTracker.progress_changed()
        link = nil
      elseif code == 200 and status == "expired" then
        link = nil
        ProgressTracker.status.line = "The code expired. Press Link for a new one."
      end
    end)
  end

  -- Called when the site says the game isn't linked any more.
  function ProgressTracker.unlinked()
    ProgressTracker.config.token = nil
    ProgressTracker.config.login = nil
    ProgressTracker.save_config()
  end

  -- Every frame ---------------------------------------------------------------

  local function profile_name(slot)
    local profile = slot and G.PROFILES and G.PROFILES[slot]
    return profile and profile.name or ("Profile " .. tostring(slot))
  end

  local function update_status()
    local status = ProgressTracker.status
    local host = SERVER:gsub("^https?://", "")
    if link and link.code then
      status.line = "Type this code on the site:"
      status.code = link.code
      status.hint = host .. "/tracker/link-game"
    else
      status.code = ""
      if ProgressTracker.is_linked() then
        status.line = "Linked to " .. tostring(ProgressTracker.config.login)
        status.hint = host .. "/tracker/" .. tostring(ProgressTracker.config.login)
      elseif not link then
        status.hint = "Press Link, then type the code on " .. host .. "/tracker"
        if status.line == "" or status.line:match("^Linked") then status.line = "Not linked" end
      end
    end
    local tracked = ProgressTracker.config.profile
    status.profile = tracked and ("Sending progress from: " .. profile_name(tracked)) or ""
    status.link_button = (link and link.code and "Open the page") or (ProgressTracker.is_linked() and "Link again") or "Link"
    status.track_button = tracked == G.SETTINGS.profile and "Tracking this profile" or "Track this profile"
  end

  local update_ref = Game.update
  function Game:update(dt)
    update_ref(self, dt)
    local now = love.timer.getTime()
    receive()
    poll_link(now)
    if ProgressTracker.send_progress then ProgressTracker.send_progress(now) end
    update_status()
  end
end
