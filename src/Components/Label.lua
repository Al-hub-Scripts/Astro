--[[ Label — static muted text. RichText enabled so consumers can accent words. ]]
return function(require)
	local Utils = require("Utils")

	return function(ctx, parent, config)
		local theme = ctx.theme
		local text = type(config) == "table" and (config.Text or "") or tostring(config)

		local root = Utils.create("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = parent,
		})
		theme:register(root, { TextColor3 = "TextMuted" })
		Utils.padding(root, 2)

		local handle = { Instance = root, Name = text, Type = "Label" }
		function handle:Set(value)
			root.Text = tostring(value)
			self.Name = tostring(value)
		end
		function handle:Get()
			return root.Text
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
