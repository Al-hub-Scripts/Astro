--[[ Toggle — knob glides across the track; track crossfades to accent on. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")

	local TRACK_W, KNOB = 40, 16

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local base = Utils.element(theme, parent, { name = config.Name or "Toggle" })
		local root, stroke = base.root, base.stroke
		root.Name = "Toggle"

		local track = Utils.create("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(TRACK_W, 20),
			BackgroundColor3 = theme:get("ElevatedHover"),
			BorderSizePixel = 0,
			Parent = root,
		})
		Utils.corner(track, UDim.new(1, 0))

		local knob = Utils.create("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 11, 0.5, 0),
			Size = UDim2.fromOffset(KNOB, KNOB),
			BackgroundColor3 = theme:get("TextPrimary"),
			BorderSizePixel = 0,
			Parent = track,
		})
		theme:register(knob, { BackgroundColor3 = "TextPrimary" })
		Utils.corner(knob, UDim.new(1, 0))

		local value = config.Default and true or false
		local callback = config.Callback

		-- The single place toggle visuals are computed (so theme swaps reuse it).
		local function apply(animate)
			local knobPos = value and UDim2.new(0, TRACK_W - 11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
			local trackColor = value and theme:get("Accent") or theme:get("ElevatedHover")
			if animate == false then
				knob.Position = knobPos
				track.BackgroundColor3 = trackColor
			else
				-- knob springs across with a soft Back overshoot; track crossfades.
				-- a quick squash-stretch (wider mid-glide) adds life without bounce.
				Animations.tween(knob, "Pop", { Position = knobPos })
				Animations.tween(track, "Toggle", { BackgroundColor3 = trackColor })
				knob.Size = UDim2.fromOffset(KNOB + 4, KNOB - 2)
				task.delay(0.12, function()
					if knob.Parent then
						Animations.tween(knob, "Pop", { Size = UDim2.fromOffset(KNOB, KNOB) })
					end
				end)
			end
		end
		apply(false)

		local hit = Utils.create("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
			Parent = root,
		})
		Utils.hoverLift(theme, root, stroke, maid)

		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(hit, config.Tooltip)
		end

		local handle = { Instance = root, Name = config.Name or "Toggle", Type = "Toggle" }
		handle._highlightStroke = stroke

		function handle:Set(state, skipCallback)
			value = state and true or false
			apply(true)
			if not skipCallback and callback then
				task.spawn(callback, value)
			end
		end
		function handle:Get()
			return value
		end
		function handle:SetVisible(visible)
			root.Visible = visible and true or false
		end
		function handle:Destroy()
			root:Destroy()
		end

		maid:give(hit.MouseButton1Click:Connect(function()
			handle:Set(not value)
		end))
		-- Track colour follows live theme swaps.
		maid:give(theme:onChanged(function(animate)
			apply(animate)
		end))

		return handle
	end
end
