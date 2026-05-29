--[[
    Loader.lua — the ONLY file an end user loadstrings:

        local Astro = loadstring(game:HttpGet(LOADER_URL))()

    It fetches every module from GitHub raw, compiles each into its factory,
    then resolves them through a string-name `require` shim (cached, so each
    module is fetched once and modules can depend on each other by name).
]]

-- ===========================================================================
--  EDIT THIS — point it at your repo + the branch/tag you want to pin to.
--  Must end with a trailing slash. Files are read from "<BASE_URL>src/<name>.lua".
-- ===========================================================================
local BASE_URL = "https://raw.githubusercontent.com/Al-hub-Scripts/Astro/refs/heads/main/"
-- ===========================================================================

-- Every module's relative name (used for both the URL and the require key).
-- Pinning this manifest means a bad partial deploy can't silently half-load.
local MODULES = {
	"Utils",
	"Animations",
	"Theme",
	"Library",
	"Components/Button",
	"Components/Toggle",
	"Components/Slider",
	"Components/Dropdown",
	"Components/Textbox",
	"Components/Keybind",
	"Components/ColorPicker",
	"Components/Label",
	"Components/Paragraph",
	"Components/Section",
	"Systems/Dragger",
	"Systems/Notifications",
	"Systems/ConfigManager",
	"Systems/Search",
	"Systems/Keybinds",
	"Systems/Tooltip",
}

local function fetch(url)
	local lastErr
	for attempt = 1, 3 do -- simple retry with light backoff
		local ok, res = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
		lastErr = res
		task.wait(0.3 * attempt)
	end
	return nil, lastErr
end

local factories = {}

local function loadModule(name)
	if factories[name] then
		return factories[name]
	end
	local url = BASE_URL .. "src/" .. name .. ".lua"
	local src, err = fetch(url)
	if not src then
		error("[Astrophysics] failed to load module " .. name .. ": " .. tostring(err))
	end
	local chunk, compileErr = loadstring(src)
	if not chunk then
		error("[Astrophysics] failed to compile module " .. name .. ": " .. tostring(compileErr))
	end
	local ok, factory = pcall(chunk)
	if not ok or type(factory) ~= "function" then
		error("[Astrophysics] failed to init module " .. name .. ": " .. tostring(factory))
	end
	factories[name] = factory
	return factory
end

-- Preload all sources up front so a missing/broken file surfaces as one clear
-- error instead of a cryptic mid-resolve stack.
for _, name in ipairs(MODULES) do
	loadModule(name)
end

local cache, resolving = {}, {}
local function resolve(name)
	if cache[name] ~= nil then
		return cache[name]
	end
	if resolving[name] then
		error("[Astrophysics] circular dependency at " .. name)
	end
	resolving[name] = true
	local result = loadModule(name)(resolve)
	resolving[name] = nil
	cache[name] = result
	return result
end

return resolve("Library")
