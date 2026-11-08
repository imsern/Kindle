<p align="center"><img src="media/logo.png" alt="Kindle" width="160"></p>

# Kindle

A World of Warcraft: Forever addon for the Camping system. Kindle shows a small movable bar with the buttons you
need right then:

- **No campfire nearby and no camp bonuses:** the **Campfire** button. It places the best campfire kit in your
  bags, or crafts the best kit you can make. With neither it's greyed out or hidden (a setting).
- **Camp bonuses up and no campfire nearby:** nothing; the bar hides.
- **Campfire nearby:** the camp object buttons and Sit:
- **Camp objects:** one button per camp object line you have, for the highest tier you can
  use. It places the object if it's in your bags, or crafts it if you know the recipe and have the materials; once
  crafted it turns into a "place" button. The tooltip shows what the object is, its camp bonus and which materials
  are missing. A green check means its bonus is on you.
- **Sit:** sits you down. Stay seated 60 seconds for Camp Benefits; the button shows the
  countdown.

Under the bar a status line shows whether a campfire is nearby and how long your camp bonuses last.

**Camp advice:** sitting at a camp replaces your camp bonuses with that camp's. At a camp, a second line rates it
for your class, e.g. "This camp: Critical Strike, Attack Power — better for melee than yours". The game doesn't tell
addons what a camp has, so **hover the camp's objects** once; Kindle also counts bonuses you gain there. Stats are
coloured by how much they matter to you (green best, grey useless). Every tier of an object gives the same stat,
higher tiers more of it, so a tier II of your own bonus counts as an upgrade. Hybrids can pick a role in the settings.

**Reminders:** a sound and on-screen message a few minutes before your camp bonuses run out (2, 5 or 10 minutes,
or off; pick the sound in the settings). At a camp, **Sit glows** when sitting would help: you have no camp
bonuses, or this camp is better for you.

**Group sharing:** what Kindle learns about a camp is shared with party or raid members at the same camp who also
run Kindle, so they get the rating without hovering everything. It uses hidden addon messages (never chat), only
outside instances, and can be turned off.

**Settings and looks:** `/kindle` opens the settings window (also under Esc > Options > AddOns): show/lock the bar,
button size, bar background, the campfire button with nothing to do, camp advice and role, and the theme. Themes:
**WoW** (the normal look), **Dark**, **Class colour**, and **EllesmereUI** / **NaowhUI** when those are installed.
**Auto** picks NaowhUI, else EllesmereUI, else WoW. A welcome guide opens on your first login (`/kindle welcome`).

Kindle knows you're in camp from the game's **Campfire Nearby** aura. It learns which recipe makes each camp item
when you open a profession window, so open each of your professions once.

Status: beta. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Install

Download `Kindle-<version>.zip` from [Releases](https://github.com/imsern/Kindle/releases) and unzip it into
`World of Warcraft\_forever_\Interface\AddOns\`, so that `Kindle.toc` sits directly inside `AddOns\Kindle`.

## Commands

| Command | What it does |
|---|---|
| `/kindle` | Open the settings window |
| `/kindle welcome` | Show the welcome guide |
| `/kindle lock` / `/kindle unlock` | Lock or unlock the bar so it can be dragged |
| `/kindle show` / `/kindle hide` | Show or hide the bar |
| `/kindle reset` | Reset position and settings (keeps learned recipes and the welcome guide seen) |
| `/kindle nokit hide` / `grey` | Campfire button when you have no kit and can't craft one |
| `/kindle detect [method]` | How Kindle knows you're in camp: `aura` (default), `always`, `never` (the last two for testing) |
| `/kindle role [role]` | What camp advice rates for: `melee`, `ranged`, `caster`, `healer`, `tank`, or `auto` (from your class) |
| `/kindle debug` | List the debug tools: `watch`, `auras`, `bags`, `trade`, `pos`, `item`, `spell`, `data`, `tips`, `advice`, `clear` |

Debug output is also saved to `WTF\Account\<ACCOUNT>\SavedVariables\Kindle.lua` (`debugLog`) when you
`/reload` or log out.

## Notes

- The bar can't change in combat (its buttons are secure); changes wait until combat ends.
- Crafting can't be started with `/cast` on Forever. A craft button opens the profession window on the recipe and
  tries to craft right away; if the game wants a click for it, click the button once more.

## License

MIT, see [LICENSE](LICENSE).
