# Andy's Progress Tracker

A [Lovely](https://github.com/ethangreen-dev/lovely-injector) mod that sends your Balatro progress to [bot.andy-balatro.com/tracker](https://bot.andy-balatro.com/tracker). That gives you:

- **A public page** at `bot.andy-balatro.com/tracker/<your twitch name>`, updated as you play. It shows every joker's best stake sticker, your decks' stakes, challenges, achievements and the game's overall progress %. You can switch it to **gold stickers only**, for All Gold Stickers runs, which also shows when each gold landed.
- **A chat command** (`!progress`, or one you pick) that [andy_balatro](https://twitch.tv/andy_balatro)'s bot answers in your Twitch chat, e.g. `Gold stickers 87/150 | Last: Blueprint (12m ago) | <link>`. You don't need Nightbot or another bot.

It doesn't need Steamodded, and works next to [Ankh](https://github.com/MathIsFun0/Ankh).

## Install

1. Install Lovely: download `lovely-x86_64-pc-windows-msvc.zip` from the [Lovely releases](https://github.com/ethangreen-dev/lovely-injector/releases) and copy `version.dll` into the Balatro game folder (Steam → Balatro → Manage → Browse local files). Skip this if you already use Ankh or other mods.
2. Download this mod (Code → Download ZIP) and unzip it into `%AppData%\Balatro\Mods`, so there's a folder in there with `lovely.toml` directly inside. The folder's name doesn't matter.
3. Start the game.

## Link it to your Twitch

1. Sign in with Twitch at [bot.andy-balatro.com/tracker](https://bot.andy-balatro.com/tracker). That also lets the bot answer in your chat. You can turn it off there.
2. In the game, open Options → Settings → **Tracker** and press **Link**. A code shows up.
3. Type the code on the site, or press **Open the page** in the game to get there with the code filled in.

The game says `Linked to <you>` and starts sending. On the site you can pick what your page and chat command show, change the command, unlink games, or remove everything.

## What it sends

Only the profile you linked on is sent, so playing on another profile doesn't touch your page. To send a different one, switch to it and press **Track this profile** in the Tracker tab.

The mod sends the profile's name, each joker's and deck's best stake (or that it's locked or undiscovered), the challenges won, the achievements and the collection count. It checks every 5 seconds and sends only when something changed.

**Achievements**: the game's achievements are Steam's, so they're already done on a fresh profile, and Ankh turns them off. So the mod keeps its own record per profile, saved in the profile itself, and shows the game's "Achievement Unlocked" popup for each one on the tracked profile. It only knows about achievements earned while it's installed. Start a fresh profile to have them all count.

## Files

`tracker.lua` (settings, linking and the network thread), `achievements.lua`, `progress.lua` (what's sent and when) and `settings.lua` (the Tracker tab). `lovely.toml` appends them to the game's `main.lua` in that order. Each file is wrapped in `do ... end`, so they share only the global `ProgressTracker` table.

Requests go over HTTPS with the `https` module Balatro ships, on a background thread, so the game never waits on the network. Set the `PROGRESS_TRACKER_URL` environment variable to point the mod at another server (e.g. `http://localhost:3000` while working on the bot). The link and token are saved in `config/progress-tracker.jkr` in the game's save folder. Errors go to `Mods\lovely\log`.

Don't use it alongside [andy-bot-balatro](https://github.com/andy-balatro/andy-bot-balatro) with its Balatro Crazy format on: both track achievements and would show each popup twice.
