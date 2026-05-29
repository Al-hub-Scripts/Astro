--[[
    Animations.lua — THE motion system. Every tween in the entire library is
    created through here. No component anywhere is allowed to type raw tween
    numbers; they reference a named preset. This is what keeps the whole UI
    feeling like one soft, cloud-like object instead of a dozen mismatched
    easings.

    Feel rules: durations live in the ~0.12–0.70s band, biased to Quad/Quart,
    EasingDirection.Out. No Bounce/Elastic — too hard for this aesthetic.
]]
return function(_require)
	local TweenService = game:GetService("TweenService")

	local E = Enum.EasingStyle
	local D = Enum.EasingDirection

	local function ti(time, style, dir)
		return TweenInfo.new(time, style, dir or D.Out)
	end

	local Animations = {}

	-- The canonical presets (spec §7.2). Tuned by feel.
	Animations.Presets = {
		Drag = ti(0.70, E.Quad), -- the soul: lag-follow drag
		WindowOpen = ti(0.45, E.Quart),
		WindowClose = ti(0.30, E.Quad),
		TabSwitch = ti(0.40, E.Quart),
		Underline = ti(0.35, E.Quart),
		Hover = ti(0.22, E.Quad),
		Press = ti(0.12, E.Quad),
		Expand = ti(0.35, E.Quart), -- dropdowns / popups unfold
		Toggle = ti(0.28, E.Quad),
		Notify = ti(0.45, E.Quart),
		Color = ti(0.30, E.Quad), -- live theme-swap crossfade
		Glow = ti(0.45, E.Quad), -- search highlight pulse out
	}

	-- Resolve a preset name OR a literal TweenInfo (so callers may pass either).
	function Animations.info(infoOrName)
		if typeof(infoOrName) == "TweenInfo" then
			return infoOrName
		end
		return Animations.Presets[infoOrName] or Animations.Presets.Hover
	end

	-- The one tween entry point. Returns the Tween so callers can chain
	-- :Completed or :Cancel.
	function Animations.tween(instance, infoOrName, properties, play)
		local tween = TweenService:Create(instance, Animations.info(infoOrName), properties)
		if play ~= false then
			tween:Play()
		end
		return tween
	end

	-- Soft press: dip a UIScale to `to` then spring back to 1 on release-ish.
	-- Returns a function to call on release.
	function Animations.press(scaler, to)
		Animations.tween(scaler, "Press", { Scale = to or 0.97 })
		return function()
			Animations.tween(scaler, "Press", { Scale = 1 })
		end
	end

	-- Search highlight: pulse a stroke up to full accent then ease it back out.
	-- Works on any UIStroke. Non-destructive; restores transparency to `rest`.
	function Animations.pulse(stroke, accent, rest)
		rest = rest or stroke.Transparency
		stroke.Color = accent
		stroke.Transparency = 0
		stroke.Thickness = 2
		task.delay(0.18, function()
			if stroke and stroke.Parent then
				Animations.tween(stroke, "Glow", { Transparency = rest, Thickness = 1 })
			end
		end)
	end

	return Animations
end
