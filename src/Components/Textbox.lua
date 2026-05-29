--[[ Textbox — focus fades in a soft accent stroke. Commits on Enter / blur. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local base = Utils.element(theme, parent, { name = config.Name or "Textbox", labelWidth = 0.4 })
		local root, stroke = base.root, base.stroke
		root.Name = "Textbox"

		local field = Utils.create("Frame", {
			Name = "Field",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.5, -12, 0, 26),
			BackgroundColor3 = theme:get("Background"),
			BorderSizePixel = 0,
			Parent = root,
		})
		theme:register(field, { BackgroundColor3 = "Background" })
		Utils.corner(field, UDim.new(0, 6))
		local fieldStroke = Utils.stroke(field, theme:get("Stroke"), 1)
		theme:register(fieldStroke, { Color = "Stroke" })

		local box = Utils.create("TextBox", {
			Name = "Input",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = config.Default or "",
			PlaceholderText = config.Placeholder or "",
			ClearTextOnFocus = config.ClearOnFocus == true,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClipsDescendants = true,
			Parent = field,
		})
		theme:register(box, { TextColor3 = "TextPrimary", PlaceholderColor3 = "TextMuted" })
		Utils.padding(box, { left = 8, right = 8 })

		local callback = config.Callback
		Utils.hoverLift(theme, root, stroke, maid)
		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(root, config.Tooltip)
		end

		maid:give(box.Focused:Connect(function()
			Animations.tween(fieldStroke, "Hover", { Color = theme:get("Accent"), Transparency = 0 })
		end))
		maid:give(box.FocusLost:Connect(function()
			Animations.tween(fieldStroke, "Hover", { Color = theme:get("Stroke") })
			if callback then
				task.spawn(callback, box.Text)
			end
		end))

		local handle = { Instance = root, Name = config.Name or "Textbox", Type = "Textbox" }
		handle._highlightStroke = stroke
		function handle:Set(text, skipCallback)
			box.Text = tostring(text or "")
			if not skipCallback and callback then
				task.spawn(callback, box.Text)
			end
		end
		function handle:Get()
			return box.Text
		end
		function handle:SetVisible(visible)
			root.Visible = visible and true or false
		end
		function handle:Destroy()
			root:Destroy()
		end
		return handle
	end
end
