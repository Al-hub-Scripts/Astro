--[[ Slider — distinctive "comet" feel: the knob follows the cursor responsively
     while the fill TRAILS behind it on a longer ease, so value changes read as a
     layered, floaty motion instead of a single rigid bar. A soft accent glow
     halos the knob, and a value bubble pops above the knob while dragging. ]]
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

		-- The trailing fill (lags the knob). A gradient gives the "comet tail"
		-- look: brighter toward the knob, dimmer at the start.
		local fill = Utils.create("Frame", {
			Name = "Fill",
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = theme:get("Accent"),
			BorderSizePixel = 0,
			Parent = trackHolder,
		})
		theme:register(fill, { BackgroundColor3 = "Accent" })
		Utils.corner(fill, UDim.new(1, 0))
		Utils.gradient(
			fill,
			ColorSequence.new(Color3.new(1, 1, 1)),
			0,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 0),
			})
		)

		-- Soft glow halo behind the knob (a scaled radial image). Fades in on grab.
		local glow = Utils.create("ImageLabel", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Image = "rbxassetid://6014261993",
			ImageColor3 = theme:get("Accent"),
			ImageTransparency = 1,
			ZIndex = 2,
			Parent = trackHolder,
		})
		theme:register(glow, { ImageColor3 = "Accent" })

		local knob = Utils.create("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = theme:get("TextPrimary"),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = trackHolder,
		})
		theme:register(knob, { BackgroundColor3 = "TextPrimary" })
		Utils.corner(knob, UDim.new(1, 0))

		-- Value bubble that pops above the knob while dragging.
		local bubble = Utils.create("Frame", {
			Name = "Bubble",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0, 0, 0.5, -12),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = theme:get("Accent"),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = trackHolder,
		})
		theme:register(bubble, { BackgroundColor3 = "Accent" })
		Utils.corner(bubble, UDim.new(0, 5))
		local bubbleScale = Utils.scaler(bubble, 0.6)
		local bubbleText = Utils.create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = format(value, suffix),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextTransparency = 1,
			Parent = bubble,
		})
		theme:register(bubbleText, { TextColor3 = "TextOnAccent" })

		local function pct()
			return (value - min) / math.max(1e-6, (max - min))
		end
		-- knob + bubble follow FAST; fill TRAILS on a longer ease → comet feel.
		local function apply(animate)
			local p = pct()
			valueLabel.Text = format(value, suffix)
			bubbleText.Text = format(value, suffix)
			if animate == false then
				fill.Size = UDim2.new(p, 0, 1, 0)
				knob.Position = UDim2.new(p, 0, 0.5, 0)
				glow.Position = UDim2.new(p, 0, 0.5, 0)
				bubble.Position = UDim2.new(p, 0, 0.5, -12)
			else
				Animations.tween(fill, "SliderFill", { Size = UDim2.new(p, 0, 1, 0) })
				Animations.tween(knob, "SliderKnob", { Position = UDim2.new(p, 0, 0.5, 0) })
				Animations.tween(glow, "SliderKnob", { Position = UDim2.new(p, 0, 0.5, 0) })
				Animations.tween(bubble, "SliderKnob", { Position = UDim2.new(p, 0, 0.5, -12) })
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
			Size = UDim2.new(0.6, -76, 0, 26),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = root,
		})

		local dragging = false
		local function setFromX(x)
			local rel = (x - trackHolder.AbsolutePosition.X) / math.max(1, trackHolder.AbsoluteSize.X)
			handle:Set(min + Utils.clamp(rel, 0, 1) * (max - min))
		end

		local function grab()
			dragging = true
			-- knob pops bigger (Back overshoot), glow blooms in, bubble springs up
			Animations.tween(knob, "Pop", { Size = UDim2.fromOffset(18, 18) })
			Animations.tween(glow, "Hover", { ImageTransparency = 0.45 })
			Animations.tween(bubble, "Pop", { BackgroundTransparency = 0 })
			Animations.tween(bubbleText, "Pop", { TextTransparency = 0 })
			Animations.tween(bubbleScale, "Pop", { Scale = 1 })
		end
		local function release()
			if not dragging then
				return
			end
			dragging = false
			Animations.tween(knob, "Pop", { Size = UDim2.fromOffset(14, 14) })
			Animations.tween(glow, "Hover", { ImageTransparency = 1 })
			Animations.tween(bubble, "Dissolve", { BackgroundTransparency = 1 })
			Animations.tween(bubbleText, "Dissolve", { TextTransparency = 1 })
			Animations.tween(bubbleScale, "Dissolve", { Scale = 0.6 })
		end

		maid:give(hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				grab()
				setFromX(input.Position.X)
			end
		end))
		maid:give(UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				setFromX(input.Position.X)
			end
		end))
		maid:give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				release()
			end
		end))
		-- subtle knob grow on hover even before grabbing
		maid:give(hit.MouseEnter:Connect(function()
			if not dragging then
				Animations.tween(knob, "Hover", { Size = UDim2.fromOffset(16, 16) })
			end
		end))
		maid:give(hit.MouseLeave:Connect(function()
			if not dragging then
				Animations.tween(knob, "Hover", { Size = UDim2.fromOffset(14, 14) })
			end
		end))

		return handle
	end
end
