--[[
    Theme.lua — the single source of truth for colors and sizing tokens, plus
    the live theme-swap engine.

    A Window owns a Theme *controller* (Theme.new). Components register their
    instances with the controller, declaring which property tracks which color
    token. On :set(name) the controller tweens every registered instance to the
    new palette — it never rebuilds the UI. Adding a theme = adding a table to
    Theme.Palettes.
]]
return function(require)
	local Animations = require("Animations")
	local TweenService = game:GetService("TweenService")

	local Theme = {}

	-- ===================== Color palettes =====================
	-- Every palette must define the SAME token set so any instance mapping is
	-- valid across all themes.
	Theme.Palettes = {
		-- Default. Derived from the reference image: near-black panel, lavender
		-- accent.
		Nebula = {
			Background = Color3.fromRGB(14, 14, 17),
			SidebarBg = Color3.fromRGB(16, 16, 20),
			Elevated = Color3.fromRGB(22, 22, 27),
			ElevatedHover = Color3.fromRGB(30, 30, 37),
			Stroke = Color3.fromRGB(34, 34, 40),
			Accent = Color3.fromRGB(140, 120, 245),
			AccentDim = Color3.fromRGB(96, 84, 170),
			TextPrimary = Color3.fromRGB(232, 232, 236),
			TextMuted = Color3.fromRGB(138, 138, 147),
			TextOnAccent = Color3.fromRGB(255, 255, 255),
			Positive = Color3.fromRGB(120, 220, 150),
			Negative = Color3.fromRGB(235, 110, 110),
			Shadow = Color3.fromRGB(0, 0, 0),
		},
		-- Cool teal alternate to prove the swap engine.
		Aurora = {
			Background = Color3.fromRGB(11, 16, 18),
			SidebarBg = Color3.fromRGB(13, 19, 21),
			Elevated = Color3.fromRGB(18, 27, 29),
			ElevatedHover = Color3.fromRGB(24, 36, 39),
			Stroke = Color3.fromRGB(30, 44, 47),
			Accent = Color3.fromRGB(94, 221, 198),
			AccentDim = Color3.fromRGB(58, 150, 134),
			TextPrimary = Color3.fromRGB(228, 240, 238),
			TextMuted = Color3.fromRGB(126, 150, 148),
			TextOnAccent = Color3.fromRGB(8, 20, 18),
			Positive = Color3.fromRGB(120, 220, 150),
			Negative = Color3.fromRGB(235, 120, 120),
			Shadow = Color3.fromRGB(0, 0, 0),
		},
		-- Warm rose alternate.
		Crimson = {
			Background = Color3.fromRGB(18, 13, 15),
			SidebarBg = Color3.fromRGB(21, 15, 17),
			Elevated = Color3.fromRGB(28, 20, 23),
			ElevatedHover = Color3.fromRGB(37, 26, 30),
			Stroke = Color3.fromRGB(46, 32, 36),
			Accent = Color3.fromRGB(240, 118, 138),
			AccentDim = Color3.fromRGB(168, 80, 96),
			TextPrimary = Color3.fromRGB(238, 230, 232),
			TextMuted = Color3.fromRGB(154, 134, 139),
			TextOnAccent = Color3.fromRGB(255, 255, 255),
			Positive = Color3.fromRGB(120, 220, 150),
			Negative = Color3.fromRGB(235, 110, 110),
			Shadow = Color3.fromRGB(0, 0, 0),
		},
	}

	-- ===================== Sizing tokens =====================
	-- Shared across all themes. The only place magic UI numbers live.
	Theme.Sizes = {
		WindowSize = UDim2.fromOffset(600, 440),
		SidebarWidth = 0.24, -- fraction of window width
		TopBarHeight = 46,
		FooterHeight = 26,
		CornerRadius = UDim.new(0, 10),
		ElementCorner = UDim.new(0, 8),
		ContentPadding = 14,
		ElementHeight = 36,
		ElementSpacing = 8,
		StrokeThickness = 1,
	}

	function Theme.list()
		local names = {}
		for name in pairs(Theme.Palettes) do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	local function clonePalette(palette)
		local copy = {}
		for token, color in pairs(palette) do
			copy[token] = color
		end
		return copy
	end

	-- ===================== Controller (per Window) =====================
	local Controller = {}
	Controller.__index = Controller

	function Theme.new(name)
		local resolved = (name and Theme.Palettes[name]) and name or "Nebula"
		local self = setmetatable({}, Controller)
		self.name = resolved
		self.colors = clonePalette(Theme.Palettes[resolved])
		self.sizes = Theme.Sizes
		self._registry = {} -- array of { inst = Instance, map = {prop = token} }
		self._listeners = {} -- fns re-applying stateful colors on swap
		return self
	end

	-- Register a callback fired after a theme swap. Components use this to
	-- re-apply colors that depend on runtime *state* (e.g. an active toggle's
	-- accent track) which the property registry can't express. Returns a
	-- disconnector.
	function Controller:onChanged(fn)
		self._listeners[fn] = true
		return function()
			self._listeners[fn] = nil
		end
	end

	function Controller:get(token)
		return self.colors[token]
	end

	function Controller:size(token)
		return self.sizes[token]
	end

	-- Register an instance so it follows theme swaps. `map` is
	-- { PropertyName = "TokenName" }. Applies current colors immediately.
	function Controller:register(inst, map)
		table.insert(self._registry, { inst = inst, map = map })
		for prop, token in pairs(map) do
			local color = self.colors[token]
			if color then
				pcall(function()
					inst[prop] = color
				end)
			end
		end
		return inst
	end

	-- Swap palette and tween every live registered instance. Destroyed
	-- instances are pruned lazily.
	function Controller:set(name, animate)
		local palette = Theme.Palettes[name]
		if not palette then
			return false
		end
		self.name = name
		self.colors = clonePalette(palette)

		local alive = {}
		for _, entry in ipairs(self._registry) do
			local inst = entry.inst
			if inst and inst.Parent ~= nil then
				table.insert(alive, entry)
				local target = {}
				for prop, token in pairs(entry.map) do
					if self.colors[token] then
						target[prop] = self.colors[token]
					end
				end
				if animate == false then
					for prop, value in pairs(target) do
						pcall(function()
							inst[prop] = value
						end)
					end
				else
					pcall(function()
						TweenService:Create(inst, Animations.Presets.Color, target):Play()
					end)
				end
			end
		end
		self._registry = alive

		for fn in pairs(self._listeners) do
			task.spawn(fn, animate, self)
		end
		return true
	end

	return Theme
end
