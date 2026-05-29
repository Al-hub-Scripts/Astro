# Astrophysics

A soft, cloud-like Roblox executor UI library. Drag-and-drop fluent API in the
spirit of Rayfield/Orion, but with a distinctive floaty motion identity — the
window lag-follows the cursor on a long ease, panels drift into place, nothing
snaps. Dark, near-black panel; lavender accent; sidebar tabs; underlined top-bar
groups; footer status bar.

> **PC only** (mouse + keyboard). One `loadstring` for the end user; a clean
> multi-module architecture under the hood.

```lua
local Astro = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/al-hub-scripts/astro/main/Loader.lua"))()

local Window = Astro:CreateWindow({ Title = "Astro", TitleAccent = "physics", Subtitle = "v1.0" })
local tab    = Window:CreateTab({ Name = "Combat" })
local group  = tab:CreateGroup({ Name = "Aim" })

group:Toggle({ Name = "Aimbot", Default = false, Flag = "aim", Callback = function(on) end })
Astro:Notify({ Title = "Loaded", Content = "Astrophysics ready", Type = "success" })
```

---

## Contents
- [Navigation model](#navigation-model)
- [Hosting on GitHub](#hosting-on-github)
- [Running locally in Studio](#running-locally-in-studio)
- [Public API](#public-api)
  - [Astro](#astro-the-library-object)
  - [Window](#window)
  - [Tab](#tab)
  - [Group](#group)
  - [Components](#components)
  - [Element handles](#element-handles)
- [Config files & profiles](#config-files--profiles)
- [Adding a theme](#adding-a-theme)
- [Adding a component](#adding-a-component)
- [Architecture](#architecture)

---

## Navigation model

The reference visual has top tabs + a grouped sidebar; Astrophysics keeps both
looks but **inverts the semantics**:

| Region | Meaning |
| --- | --- |
| **Left sidebar** | **Tabs** — top-level categories (primary nav). Optional muted section headers. |
| **Top bar** | **Groups** of the active tab — horizontal items with an animated accent underline. |
| **Content area** | Elements of the active group (scrolls, auto-sizes). |
| **Top-right** | `search` · `minimize` · `close`. |

Switching the left tab repopulates the top groups and glides the underline.
Global search spans every tab → group → element and navigates + pulses the match.

---

## Hosting on GitHub

1. Push this repository (the `Loader.lua` at root and the whole `src/` tree) to
   GitHub. The raw URL for a file is:

   ```
   https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH-OR-TAG>/<PATH>
   ```

2. Open **`Loader.lua`** and set the one clearly-marked constant at the top:

   ```lua
   -- Must end with a trailing slash. Files load from "<BASE_URL>src/<name>.lua".
   local BASE_URL = "https://raw.githubusercontent.com/al-hub-scripts/astro/main/"
   ```

   - **Pin to a branch or tag** (`main`, `v1.0`, …) so consumers don't break on
     unrelated pushes. For a tagged release use e.g. `.../astro/v1.0/`.
   - While developing on a feature branch, point it at that branch
     (`.../astro/<branch>/`), then switch back to `main`/a tag for release.

3. The loader pulls every module listed in its **manifest** (`MODULES`) from
   `"<BASE_URL>src/<name>.lua"`, compiles each, and resolves them through a
   cached `require(name)` shim. If a file is missing or fails to compile you get
   one clear error — `"[Astrophysics] failed to load module X: …"` — instead of a
   cryptic stack. Each fetch retries up to 3× with light backoff.

   The manifest is the source of truth for what gets deployed:

   ```
   Utils  Animations  Theme  Library
   Components/{Button,Toggle,Slider,Dropdown,Textbox,Keybind,ColorPicker,Label,Paragraph,Section}
   Systems/{Dragger,Notifications,ConfigManager,Search,Keybinds,Tooltip}
   ```

That's it — the end user only ever runs `loadstring(game:HttpGet(LOADER_URL))()`.

---

## Running locally in Studio

No HTTP needed. `src/init.lua` is the local entry point. Lay the source out as
ModuleScripts (Rojo does this automatically — a folder with `init.lua` becomes a
ModuleScript, siblings become children):

```
Astrophysics (ModuleScript ← src/init.lua)
├── Utils         Animations      Theme        Library   (ModuleScripts)
├── Components/   (Folder of ModuleScripts)
└── Systems/      (Folder of ModuleScripts)
```

```lua
local Astro = require(path.to.Astrophysics)
```

Every module is authored as a factory `return function(require) ... end`. Both
`Loader.lua` and `init.lua` hand each factory the same **string-name resolver**,
so internal calls like `require("Components/Button")` work identically whether
fetched over HTTP or required in Studio.

---

## Public API

### `Astro` (the library object)

| Member | Description |
| --- | --- |
| `Astro:CreateWindow(config)` → `Window` | Build a window. |
| `Astro:Notify(options)` | Standalone toast; uses the most recent window, or its own layer. |
| `Astro.Version` | Version string. |
| `Astro.Themes` | Array of available theme names. |

**`CreateWindow` config**

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | string | `"Astro"` | Wordmark, normal weight. |
| `TitleAccent` | string | `"physics"` | Wordmark, accent-coloured. |
| `Subtitle` | string | nil | Small muted text under the wordmark. |
| `ToggleKey` | `KeyCode` | `RightShift` | Global show/hide key. |
| `Theme` | string | `"Nebula"` | Starting theme. |
| `ConfigFolder` | string | `"Astrophysics"` | Root folder for saved configs. |
| `AutoLoad` | bool | false | Load the autoload profile on open. |
| `Status` | string | `"Ready"` | Initial footer status text. |

### `Window`

| Method | Description |
| --- | --- |
| `Window:CreateTab({ Name, Icon? })` → `Tab` | Add a sidebar tab. `Icon` is an `rbxassetid://`. |
| `Window:Section(name)` | Add a muted uppercase header to the sidebar. |
| `Window:SetTheme(name [, animate])` | Swap theme; tweens every live instance. |
| `Window:SetToggleKey(keycode)` | Rebind the global show/hide key. |
| `Window:SetStatus(text)` | Set footer status text. |
| `Window:Notify(options)` | Toast on this window. |
| `Window:Show()` / `Window:Hide()` / `Window:Toggle()` | Animated open/close. |
| `Window:Minimize()` | Collapse/expand to the title bar. |
| `Window:Destroy()` | Full teardown: disconnects everything, removes the UI. |
| `Window.config` | The `ConfigManager` (see below). |

### `Tab`

| Method | Description |
| --- | --- |
| `Tab:CreateGroup({ Name })` → `Group` | Add a top-bar group to this tab. |

### `Group`

Every element method returns an [element handle](#element-handles).

| Method | Key params |
| --- | --- |
| `Group:Button({ Name, Callback, Tooltip? })` | — |
| `Group:Toggle({ Name, Default, Flag?, Callback(bool), Tooltip? })` | — |
| `Group:Slider({ Name, Min, Max, Default, Increment?, Suffix?, Flag?, Callback(num) })` | — |
| `Group:Dropdown({ Name, Options, Multi?, Default?, Placeholder?, Flag?, Callback(value\|table) })` | single + multi |
| `Group:Textbox({ Name, Placeholder?, Default?, ClearOnFocus?, Flag?, Callback(text) })` | — |
| `Group:Keybind({ Name, Default(KeyCode), Flag?, Callback(), OnChanged(KeyCode)? })` | routes through the keybind registry |
| `Group:ColorPicker({ Name, Default(Color3), Flag?, Callback(Color3) })` | HSV field + hue strip |
| `Group:Label(text)` | static muted text (RichText) |
| `Group:Paragraph({ Title, Body })` | titled wrapped block |
| `Group:Section({ Name })` or `Group:Section("Name")` | divider/header |

`Flag` opts an element into config persistence. `Tooltip` (string) adds a soft
hover tooltip to most interactive components.

### Components

- **Button** — soft press dip + accent wash that fades out.
- **Toggle** — knob glides; track crossfades to accent on.
- **Slider** — fill + knob ease to value; glides while dragging.
- **Dropdown** — soft inline unfold; single select collapses on pick, multi shows
  filled checkboxes and stays open; long lists scroll. `handle:SetOptions(list)`.
- **Textbox** — focus fades in an accent stroke; commits on Enter / blur.
- **Keybind** — click → "press a key…"; `Backspace`/`Delete` unbinds, `Escape`
  cancels. Fires `Callback` when the key is pressed; `OnChanged` when rebound.
- **ColorPicker** — saturation/value field + hue strip, live preview swatch.
- **Label / Paragraph / Section** — text + structure.
- **Tooltip** — per-element via the `Tooltip` config string.

### Element handles

Every component returns a handle:

| Member | Description |
| --- | --- |
| `handle:Set(value [, skipCallback])` | Set value through the UI (animates). Skips the callback if `skipCallback` is true. |
| `handle:Get()` | Current value. |
| `handle:SetVisible(bool)` | Show/hide the element. |
| `handle:Destroy()` | Remove the element. |
| `handle.Instance` | Root `GuiObject`. |
| `handle.Type` / `handle.Name` | Component type / display name. |

Value types by component: Toggle→`bool`, Slider→`number`, Dropdown→`string`
(single) / `array` (multi), Textbox→`string`, Keybind→`KeyCode`,
ColorPicker→`Color3`, Button→its callback.

```lua
local t = group:Toggle({ Name = "X", Default = false })
t:Set(true)        -- animates the knob, fires the callback
print(t:Get())     -- true
```

---

## Config files & profiles

When an element has a `Flag`, its value is registered with the window's
`ConfigManager` (`Window.config`).

- **Storage layout** under your executor's workspace folder:

  ```
  <ConfigFolder>/
  ├── autoload.txt          -- name of the profile to AutoLoad
  └── configs/
      ├── default.json
      └── <profile>.json    -- { "values": { "<flag>": <serialized value>, ... } }
  ```

- `Color3` and `KeyCode` values are serialized to tagged tables
  (`{__t="Color3", …}` / `{__t="KeyCode", name=…}`) since JSON can't hold them.
- **Load applies values through each component's `:Set()`**, so the UI animates
  to the loaded state and feature callbacks fire.
- If the executor lacks the file API (`writefile`/`readfile`/`isfile`/`listfiles`/…),
  persistence **silently no-ops** — the library still works in memory.

```lua
Window.config:save("pvp")          -- write a profile
Window.config:load("pvp")          -- apply it
Window.config:list()               -- { "default", "pvp", ... }
Window.config:delete("pvp")
Window.config:setAutoload("pvp")   -- load it next time (with AutoLoad = true)
```

---

## Adding a theme

A theme is just a table. Add an entry to `Theme.Palettes` in `src/Theme.lua`
defining the **same token set** as the others:

```lua
Theme.Palettes.Ocean = {
    Background = Color3.fromRGB(10, 14, 20),  SidebarBg = Color3.fromRGB(12, 16, 24),
    Elevated   = Color3.fromRGB(16, 22, 32),  ElevatedHover = Color3.fromRGB(22, 30, 44),
    Stroke     = Color3.fromRGB(28, 38, 54),  Accent = Color3.fromRGB(86, 156, 255),
    AccentDim  = Color3.fromRGB(54, 100, 168),
    TextPrimary = Color3.fromRGB(228, 236, 246), TextMuted = Color3.fromRGB(126, 140, 160),
    TextOnAccent = Color3.fromRGB(255, 255, 255),
    Positive = Color3.fromRGB(120, 220, 150), Negative = Color3.fromRGB(235, 110, 110),
    Shadow   = Color3.fromRGB(0, 0, 0),
}
```

It appears in `Astro.Themes` automatically and `Window:SetTheme("Ocean")` will
tween every live instance to it. Colours are applied to instances declaratively
via `theme:register(instance, { Property = "Token" })`, so any new palette works
with no extra wiring. Sizing tokens are shared in `Theme.Sizes`.

## Adding a component

1. Create `src/Components/MyThing.lua` as a factory returning a constructor:

   ```lua
   return function(require)
       local Utils = require("Utils")
       local Animations = require("Animations")
       return function(ctx, parent, config)
           -- ctx = { theme, maid, window, library, config, keybinds, tooltip, notify }
           local base = Utils.element(ctx.theme, parent, { name = config.Name })
           Utils.hoverLift(ctx.theme, base.root, base.stroke, ctx.maid)
           -- build your control on base.root; pull colours from ctx.theme:get(token)
           -- and animate ONLY via Animations.tween(inst, "PresetName", props)

           local value
           local handle = { Instance = base.root, Name = config.Name, Type = "MyThing" }
           handle._highlightStroke = base.stroke              -- for search pulse
           function handle:Set(v, skipCallback) --[[ update UI; fire config.Callback ]] end
           function handle:Get() return value end
           function handle:SetVisible(b) base.root.Visible = b and true or false end
           function handle:Destroy() base.root:Destroy() end
           return handle
       end
   end
   ```

2. Register it in **`src/Library.lua`** (the `Components` map) and in
   **`src/init.lua`** (the factories map), then add `"Components/MyThing"` to the
   **`MODULES`** manifest in **`Loader.lua`**.

3. Add a `Group:MyThing(config)` wrapper next to the others in `Library.lua`.

**Rules of the house:** never type raw tween numbers — reference an
`Animations.Presets` name; never hardcode colours/sizes — pull from theme tokens;
track every connection/instance via `ctx.maid` so `Window:Destroy()` stays
leak-free.

---

## Architecture

```
Loader.lua                 -- single HTTP entry: fetch + compile + require shim
src/
├── init.lua               -- Studio require() entry (same resolver)
├── Library.lua            -- Window/Tab/Group, mounting, public API
├── Theme.lua              -- color + size tokens, palettes, live-swap controller
├── Animations.lua         -- the motion system: every tween preset + helpers
├── Utils.lua              -- create(), Maid, Signal, safe parenting, element/hover
├── Components/            -- Button, Toggle, Slider, Dropdown, Textbox,
│                             Keybind, ColorPicker, Label, Paragraph, Section
└── Systems/
    ├── Dragger.lua        -- canonical cloud-like trailing drag
    ├── ConfigManager.lua  -- flags, save/load, profiles, autoload
    ├── Notifications.lua  -- queued toasts with soft reflow
    ├── Search.lua         -- global search index + navigate/highlight
    ├── Keybinds.lua       -- one global listener; toggle key + bind registry
    └── Tooltip.lua        -- hover tooltips
```

- **Motion is centralized** in `Animations.lua` — durations live in the
  ~0.12–0.70s band, biased to Quad/Quart, `EasingDirection.Out`. The drag
  (`0.70 Quad/Out`, retargeted every frame) is the reference feel everything else
  matches.
- **One source of truth** for colours/sizes (`Theme`) and tweens (`Animations`).
- **No leaks:** a per-window `Maid` tracks every connection and instance;
  `Window:Destroy()` cleans it and removes the UI.
- **Degrades gracefully:** every executor-specific call (`gethui`,
  `syn.protect_gui`, file API) is guarded with a fallback.

See `Example.lua` for a full demo wiring real ESP / Fly / WalkSpeed / Settings
features end to end.
