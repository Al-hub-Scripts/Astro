--[[ ColorPicker — the picker POPS OUT of the GUI as a floating panel (via the
     window's popup layer) instead of expanding inline. HSV saturation/value
     field + hue strip + live RGB readout, blooming out over the panel from the
     swatch. Falls back to inline expand only if no popup host is available. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	local POPUP_W = 200
	local POPUP_H = 184

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local h, s, v = (config.Default or Color3.fromRGB(255, 80, 80)):ToHSV()
		local callback = config.Callback

		-- ---------- header row (always visible) ----------
		local base = Utils.element(theme, parent, { name = config.Name or "Color", labelWidth = 0.6 })
		local root, stroke = base.root, base.stroke
		root.Name = "ColorPicker"

		local chevron = Utils.create("TextLabel", {
			Name = "Chevron",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(10, 16),
			BackgroundTransparency = 1,
			Text = "›",
			Rotation = 90,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Parent = root,
		})
		theme:register(chevron, { TextColor3 = "TextMuted" })

		local swatch = Utils.create("Frame", {
			Name = "Swatch",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -30, 0.5, 0),
			Size = UDim2.fromOffset(30, 18),
			BackgroundColor3 = Color3.fromHSV(h, s, v),
			BorderSizePixel = 0,
			Parent = root,
		})
		Utils.corner(swatch, UDim.new(0, 5))
		local swStroke = Utils.stroke(swatch, theme:get("Stroke"), 1)
		theme:register(swStroke, { Color = "Stroke" })
		local swatchScale = Utils.scaler(swatch, 1)

		local handle = { Instance = root, Name = config.Name or "Color", Type = "ColorPicker" }
		handle._highlightStroke = stroke

		-- ---------- popup body ----------
		local hasPopup = ctx.createPopup ~= nil
		local popup = hasPopup and ctx.createPopup(swatch, UDim2.fromOffset(POPUP_W, POPUP_H), {
			onOpen = function()
				Animations.tween(chevron, "Bloom", { Rotation = 270 })
				Animations.tween(swatchScale, "Pop", { Scale = 1.12 })
			end,
			onClose = function()
				Animations.tween(chevron, "Bloom", { Rotation = 90 })
				Animations.tween(swatchScale, "Pop", { Scale = 1 })
			end,
		}) or nil

		-- container we build the picker UI into (popup frame, or an inline panel)
		local body
		if hasPopup then
			body = popup.frame
			Utils.padding(body, 12)
		else
			-- fallback: inline expander
			root.ClipsDescendants = true
			root.AutomaticSize = Enum.AutomaticSize.None
			body = Utils.create("Frame", {
				Name = "Inline",
				Position = UDim2.new(0, 12, 0, 42),
				Size = UDim2.new(1, -24, 0, POPUP_H - 24),
				BackgroundTransparency = 1,
				Parent = root,
			})
		end

		-- ---------- SV field ----------
		local svBase = Utils.create("Frame", {
			Name = "SV",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = body,
		})
		Utils.corner(svBase, UDim.new(0, 6))
		local satOverlay = Utils.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = svBase,
		})
		Utils.corner(satOverlay, UDim.new(0, 6))
		Utils.gradient(
			satOverlay,
			ColorSequence.new(Color3.new(1, 1, 1)),
			0,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
		)
		local valOverlay = Utils.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = svBase,
		})
		Utils.corner(valOverlay, UDim.new(0, 6))
		Utils.gradient(
			valOverlay,
			ColorSequence.new(Color3.new(0, 0, 0)),
			90,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})
		)
		local svDot = Utils.create("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = svBase,
		})
		Utils.corner(svDot, UDim.new(1, 0))
		Utils.stroke(svDot, Color3.new(1, 1, 1), 2)

		-- ---------- Hue strip ----------
		local hueBar = Utils.create("Frame", {
			Name = "Hue",
			Position = UDim2.fromOffset(0, 106),
			Size = UDim2.new(1, 0, 0, 12),
			BorderSizePixel = 0,
			Parent = body,
		})
		Utils.corner(hueBar, UDim.new(1, 0))
		Utils.gradient(
			hueBar,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromHSV(0.0, 1, 1)),
				ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
				ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
				ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
				ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
				ColorSequenceKeypoint.new(1.0, Color3.fromHSV(1.0, 1, 1)),
			})
		)
		local hueDot = Utils.create("Frame", {
			Name = "HueDot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 1, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = hueBar,
		})
		Utils.corner(hueDot, UDim.new(1, 0))

		-- ---------- RGB readout ----------
		local rgbLabel = Utils.create("TextLabel", {
			Name = "RGB",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		})
		theme:register(rgbLabel, { TextColor3 = "TextMuted" })

		local function update(fireCallback)
			local color = Color3.fromHSV(h, s, v)
			swatch.BackgroundColor3 = color
			svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			svDot.Position = UDim2.new(s, 0, 1 - v, 0)
			hueDot.Position = UDim2.new(h, 0, 0.5, 0)
			rgbLabel.Text = string.format(
				"R %d   G %d   B %d",
				math.floor(color.R * 255 + 0.5),
				math.floor(color.G * 255 + 0.5),
				math.floor(color.B * 255 + 0.5)
			)
			if fireCallback and callback then
				task.spawn(callback, color)
			end
		end
		update(false)

		-- ---------- open/close ----------
		local inlineOpen = false
		local function setOpen(state)
			if hasPopup then
				if state then
					popup.open()
				else
					popup.close()
				end
			else
				inlineOpen = state
				Animations.tween(root, "Bloom", {
					Size = UDim2.new(1, 0, 0, state and POPUP_H + 8 or theme:size("ElementHeight")),
				})
				Animations.tween(chevron, "Bloom", { Rotation = state and 270 or 90 })
			end
		end
		local function isOpen()
			return hasPopup and popup.isOpen() or inlineOpen
		end

		local hit = Utils.create("TextButton", {
			Name = "Hit",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 70, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 4,
			Parent = root,
		})
		Utils.hoverLift(theme, root, stroke, maid)
		maid:give(hit.MouseButton1Click:Connect(function()
			setOpen(not isOpen())
		end))
		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(hit, config.Tooltip)
		end

		-- ---------- dragging the SV / hue ----------
		local dragTarget = nil -- "sv" | "hue"
		local function updateFromInput(x, y)
			if dragTarget == "sv" then
				s = Utils.clamp((x - svBase.AbsolutePosition.X) / math.max(1, svBase.AbsoluteSize.X), 0, 1)
				v = 1 - Utils.clamp((y - svBase.AbsolutePosition.Y) / math.max(1, svBase.AbsoluteSize.Y), 0, 1)
				update(true)
			elseif dragTarget == "hue" then
				h = Utils.clamp((x - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1)
				update(true)
			end
		end
		maid:give(svBase.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragTarget = "sv"
				Animations.tween(svDot, "Pop", { Size = UDim2.fromOffset(14, 14) })
				updateFromInput(input.Position.X, input.Position.Y)
			end
		end))
		maid:give(hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragTarget = "hue"
				updateFromInput(input.Position.X, input.Position.Y)
			end
		end))
		maid:give(UserInputService.InputChanged:Connect(function(input)
			if dragTarget and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateFromInput(input.Position.X, input.Position.Y)
			end
		end))
		maid:give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if dragTarget == "sv" then
					Animations.tween(svDot, "Pop", { Size = UDim2.fromOffset(10, 10) })
				end
				dragTarget = nil
			end
		end))

		function handle:Set(color, skipCallback)
			if typeof(color) == "Color3" then
				h, s, v = color:ToHSV()
				update(not skipCallback)
			end
		end
		function handle:Get()
			return Color3.fromHSV(h, s, v)
		end
		function handle:SetVisible(visible)
			root.Visible = visible and true or false
		end
		function handle:Destroy()
			if popup then
				popup.close(true)
				popup.holder:Destroy()
			end
			root:Destroy()
		end
		return handle
	end
end
