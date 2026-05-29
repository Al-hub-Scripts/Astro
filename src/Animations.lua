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

		-- Distinctive presets — the "cloud" motion language.
		-- Back/Out has a fixed overshoot; we only apply it to SMALL deltas
		-- (scale 0.85→1, knob +4px) so it reads as a gentle settle/pop, never a
		-- cartoon bounce. This is the signature that separates us from the
		-- universal fade-scale.
		Bloom = ti(0.52, E.Back), -- popups + window open: spring/bloom outward
		Pop = ti(0.26, E.Back), -- knob grab, value label, swatch micro-pops
		Fold = ti(0.46, E.Quart), -- minimize: vertical fold
		Dissolve = ti(0.34, E.Quad), -- close / popup-out: evaporate
		SliderKnob = ti(0.10, E.Quad), -- knob: snappy follow under the cursor
		SliderFill = ti(0.40, E.Quart), -- fill: trails the knob → layered, floaty
		Drift = ti(0.60, E.Quad), -- long soft positional drifts
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

	-- Stagger children into place: each child drifts up + fades on a tiny
	-- escalating delay so a freshly-populated list/popup "cascades" in rather
	-- than appearing all at once. This is a big part of the unique feel.
	-- `items` = array of { inst, from? (UDim2 offset), props? }.
	function Animations.cascade(items, step, infoName)
		step = step or 0.035
		for i, item in ipairs(items) do
			local inst = item.inst or item
			if inst and inst.Parent then
				local restPos = inst.Position
				inst.Position = restPos + (item.from or UDim2.fromOffset(0, 10))
				if inst:IsA("CanvasGroup") then
					inst.GroupTransparency = 1
				end
				task.delay((i - 1) * step, function()
					if not inst.Parent then
						return
					end
					Animations.tween(inst, infoName or "Bloom", { Position = restPos })
					if inst:IsA("CanvasGroup") then
						Animations.tween(inst, infoName or "Bloom", { GroupTransparency = 0 })
					end
				end)
			end
		end
	end

	-- Floating popup bloom-in: a CanvasGroup popup scales from a pivot + fades.
	-- Uses a UIScale so the bloom doesn't disturb layout. `originScale` lets it
	-- look like it grew out of its anchor element.
	function Animations.bloomIn(popup, scaler)
		scaler.Scale = 0.82
		popup.GroupTransparency = 1
		popup.Visible = true
		Animations.tween(scaler, "Bloom", { Scale = 1 })
		Animations.tween(popup, "Bloom", { GroupTransparency = 0 })
	end

	-- Reverse: evaporate the popup (scale down slightly + fade), hide on done.
	function Animations.bloomOut(popup, scaler, onDone)
		Animations.tween(scaler, "Dissolve", { Scale = 0.9 })
		local tw = Animations.tween(popup, "Dissolve", { GroupTransparency = 1 })
		tw.Completed:Connect(function()
			popup.Visible = false
			if onDone then
				onDone()
			end
		end)
		return tw
	end

	return Animations
end
