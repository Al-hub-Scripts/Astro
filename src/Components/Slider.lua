--[[ Slider — fill + knob ease to the value. While dragging we glide on a short
     tween so it floats to the cursor instead of snapping/jittering. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	local function format(value, suffix)
		local text
		if math.abs(value - math.floor(value)) < 1e-4 then
			text = tostring(math.floor(value))
		else
			text = string.format("%.2f", value):gsub("%.?0+$", "")
		end
		return text .. (suffix or "")
	end

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local min = config.Min or 0
		local max = config.Max or 100
		local increment = config.Increment or 1
		local suffix = config.Suffix or ""
		local value = Utils.clamp(config.Default or min, min, max)
		local callback = config.Callback

		local base = Utils.element(theme, parent, { name = config.Name or "Slider", labelWidth = 0.4 })
		local root, stroke = base.root, base.stroke
		root.Name = "Slider"

		local valueLabel = Utils.create("TextLabel", {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 50, 1, 0),
			BackgroundTransparency = 1,
			Text = format(value, suffix),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = root,
		})
		theme:register(valueLabel, { TextColor3 = "TextMuted" })

		local trackHolder = Utils.create("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.4, 6, 0.5, 0),
			Size = UDim2.new(0.6, -76, 0, 6),
			BackgroundColor3 = theme:get("ElevatedHover"),
			BorderSizePixel = 0,
			Parent = root,
		})
		theme:register(trackHolder, { BackgroundColor3 = "ElevatedHover" })
		Utils.corner(trackHolder, UDim.new(1, 0))

		local fill = Utils.create("Frame", {
			Name = "Fill",
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = theme:get("Accent"),
			BorderSizePixel = 0,
			Parent = trackHolder,
		})
		theme:register(fill, { BackgroundColor3 = "Accent" })
		Utils.corner(fill, UDim.new(1, 0))

		local knob = Utils.create("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = theme:get("TextPrimary"),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = trackHolder,
		})
		theme:register(knob, { BackgroundColor3 = "TextPrimary" })
		Utils.corner(knob, UDim.new(1, 0))

		local function pct()
			return (value - min) / math.max(1e-6, (max - min))
		end
		local function apply(animate)
			local p = pct()
			valueLabel.Text = format(value, suffix)
			if animate == false then
				fill.Size = UDim2.new(p, 0, 1, 0)
				knob.Position = UDim2.new(p, 0, 0.5, 0)
			else
				-- short glide → floats to value, never jitters
				Animations.tween(fill, "Press", { Size = UDim2.new(p, 0, 1, 0) })
				Animations.tween(knob, "Press", { Position = UDim2.new(p, 0, 0.5, 0) })
			end
		end
		apply(false)

		Utils.hoverLift(theme, root, stroke, maid)
		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(root, config.Tooltip)
		end

		local handle = { Instance = root, Name = config.Name or "Slider", Type = "Slider" }
		handle._highlightStroke = stroke

		function handle:Set(newValue, skipCallback)
			value = Utils.clamp(Utils.round(tonumber(newValue) or value, increment), min, max)
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

		-- Drag handling on an enlarged invisible hit strip.
		local hit = Utils.create("TextButton", {
			Name = "Hit",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.4, 6, 0.5, 0),
			Size = UDim2.new(0.6, -76, 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
			Parent = root,
		})

		local dragging = false
		local function setFromX(x)
			local rel = (x - trackHolder.AbsolutePosition.X) / math.max(1, trackHolder.AbsoluteSize.X)
			handle:Set(min + Utils.clamp(rel, 0, 1) * (max - min))
		end
		maid:give(hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				Animations.tween(knob, "Hover", { Size = UDim2.fromOffset(16, 16) })
				setFromX(input.Position.X)
			end
		end))
		maid:give(UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				setFromX(input.Position.X)
			end
		end))
		maid:give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
				dragging = false
				Animations.tween(knob, "Hover", { Size = UDim2.fromOffset(14, 14) })
			end
		end))

		return handle
	end
end
