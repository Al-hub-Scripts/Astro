--[[ Paragraph — a titled block of wrapped body text inside an Elevated card. ]]
return function(require)
	local Utils = require("Utils")

	return function(ctx, parent, config)
		local theme = ctx.theme

		local root = Utils.create("Frame", {
			Name = "Paragraph",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme:get("Elevated"),
			BorderSizePixel = 0,
			Parent = parent,
		})
		theme:register(root, { BackgroundColor3 = "Elevated" })
		Utils.corner(root, theme:size("ElementCorner"))
		local stroke = Utils.stroke(root, theme:get("Stroke"), theme:size("StrokeThickness"))
		theme:register(stroke, { Color = "Stroke" })
		Utils.padding(root, { top = 10, bottom = 10, left = 12, right = 12 })
		Utils.layout(root, Enum.FillDirection.Vertical, 4)

		local title = Utils.create("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = config.Title or "Title",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = root,
		})
		theme:register(title, { TextColor3 = "TextPrimary" })

		local body = Utils.create("TextLabel", {
			Name = "Body",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = config.Body or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = root,
		})
		theme:register(body, { TextColor3 = "TextMuted" })

		local handle = { Instance = root, Name = config.Title or "Paragraph", Type = "Paragraph" }
		function handle:Set(value)
			if type(value) == "table" then
				if value.Title then
					title.Text = value.Title
				end
				if value.Body then
					body.Text = value.Body
				end
			else
				body.Text = tostring(value)
			end
		end
		function handle:Get()
			return { Title = title.Text, Body = body.Text }
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
