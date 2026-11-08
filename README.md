# Kindle

A World of Warcraft: Forever addon for the Camping system. When you're near a campsite, Kindle shows a small
movable bar with the buttons you need right then: place or craft a campfire kit, place or craft your
profession objects, and sit down so the camp buffs apply.

Status: early development. The bar and buttons aren't built yet.

## Install

Copy the `Kindle` folder to `World of Warcraft\_forever_\Interface\AddOns\` so that `Kindle.toc` sits directly
inside `AddOns\Kindle`.

## Commands

| Command | What it does |
|---|---|
| `/kindle lock` / `/kindle unlock` | Lock or unlock the bar so it can be dragged |
| `/kindle show` / `/kindle hide` | Show or hide the bar |
| `/kindle reset` | Reset position and settings |
| `/kindle debug` | List the debug tools: `watch`, `auras`, `bags`, `skills`, `trade`, `pos`, `item`, `spell`, `data`, `clear` |

Debug output is also saved to `WTF\Account\<ACCOUNT>\SavedVariables\Kindle.lua` (`debugLog`) when you
`/reload` or log out.

## License

MIT, see [LICENSE](LICENSE).
