--[[
    src/init.lua — local require() entry point for Roblox Studio development
    (no HTTP). Arrange the source as ModuleScripts (e.g. via Rojo): this file
    becomes the parent ModuleScript, with Utils/Animations/Theme/Library as
    sibling children and Components/ + Systems/ as child folders.

    Every module returns a factory `function(require) -> moduleTable`. We hand
    each factory a string-name resolver so internal `require("Components/Button")`
    style calls work identically here and in Loader.lua.
]]
local root = script

local factories = {
	["Utils"] = require(root.Utils),
	["Animations"] = require(root.Animations),
	["Theme"] = require(root.Theme),
	["Library"] = require(root.Library),

	["Components/Button"] = require(root.Components.Button),
	["Components/Toggle"] = require(root.Components.Toggle),
	["Components/Slider"] = require(root.Components.Slider),
	["Components/Dropdown"] = require(root.Components.Dropdown),
	["Components/Textbox"] = require(root.Components.Textbox),
	["Components/Keybind"] = require(root.Components.Keybind),
	["Components/ColorPicker"] = require(root.Components.ColorPicker),
	["Components/Label"] = require(root.Components.Label),
	["Components/Paragraph"] = require(root.Components.Paragraph),
	["Components/Section"] = require(root.Components.Section),

	["Systems/Dragger"] = require(root.Systems.Dragger),
	["Systems/Notifications"] = require(root.Systems.Notifications),
	["Systems/ConfigManager"] = require(root.Systems.ConfigManager),
	["Systems/Search"] = require(root.Systems.Search),
	["Systems/Keybinds"] = require(root.Systems.Keybinds),
	["Systems/Tooltip"] = require(root.Systems.Tooltip),
}

local cache, resolving = {}, {}
local function resolve(name)
	if cache[name] ~= nil then
		return cache[name]
	end
	local factory = factories[name]
	if not factory then
		error("[Astrophysics] unknown module: " .. tostring(name))
	end
	if resolving[name] then
		error("[Astrophysics] circular dependency at " .. name)
	end
	resolving[name] = true
	local result = factory(resolve)
	resolving[name] = nil
	cache[name] = result
	return result
end

return resolve("Library")
