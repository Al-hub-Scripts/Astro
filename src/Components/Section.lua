--[[ Section — a divider/header inside a group. A small bold title with a thin
     rule beneath it to break up dense pages. ]]
return function(require)
	local Utils = require("Utils")

	return function(ctx, parent, config)
		local theme = ctx.theme

		local root = Utils.create("Frame", {
			Name = "Section",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Parent = parent,
		})

		local title = Utils.create("TextLabel", {
			Name = "Title",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 2, 0, 4),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = config.Name or "Section",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = root,
		})
		theme:register(title, { TextColor3 = "TextPrimary" })

		local rule = Utils.create("Frame", {
			Name = "Rule",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			Parent = root,
		})
		theme:register(rule, { BackgroundColor3 = "Stroke" })

		local handle = { Instance = root, Name = config.Name or "Section", Type = "Section" }
		function handle:Set(value)
			title.Text = tostring(value)
			self.Name = tostring(value)
		end
		function handle:Get()
			return title.Text
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
