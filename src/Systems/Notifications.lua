--[[ Notifications — queued toasts that drift in from the right edge + fade, auto
     dismiss, and reflow the stack softly. Stacking is manual (not a UIListLayout)
     so each toast can be position-tweened for the drift + soft reflow. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")

	local Notifications = {}
	Notifications.__index = Notifications

	local WIDTH = 280
	local GAP = 8
	local DRIFT = 60 -- offscreen-right start offset

	local TYPE_TOKEN = {
		info = "Accent",
		success = "Positive",
		error = "Negative",
	}

	function Notifications.new(ctx)
		local self = setmetatable({}, Notifications)
		self.theme = ctx.theme
		self._active = {} -- ordered; last = newest (bottom)

		local container = Utils.create("Frame", {
			Name = "Toasts",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, WIDTH, 1, -32),
			BackgroundTransparency = 1,
			ZIndex = 40,
			Parent = ctx.screenGui,
		})
		self._container = container
		return self
	end

	-- Recompute every toast's slot from the bottom up and glide it there.
	function Notifications:_reflow()
		local accum = 0
		for i = #self._active, 1, -1 do
			local toast = self._active[i]
			Animations.tween(toast.card, "Notify", {
				Position = UDim2.new(1, 0, 1, -accum),
			})
			accum = accum + toast.height + GAP
		end
	end

	function Notifications:_dismiss(toast)
		if toast._dismissed then
			return
		end
		toast._dismissed = true
		Animations.tween(toast.card, "Notify", {
			Position = UDim2.new(1, DRIFT, 1, toast.card.Position.Y.Offset),
			GroupTransparency = 1,
		})
		task.delay(0.32, function()
			local idx = table.find(self._active, toast)
			if idx then
				table.remove(self._active, idx)
			end
			toast.card:Destroy()
			self:_reflow()
		end)
	end

	function Notifications:Notify(options)
		options = options or {}
		local theme = self.theme
		local accentToken = TYPE_TOKEN[options.Type] or "Accent"

		local card = Utils.create("CanvasGroup", {
			Name = "Toast",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, DRIFT, 1, 0),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme:get("Elevated"),
			GroupTransparency = 1,
			Parent = self._container,
		})
		theme:register(card, { BackgroundColor3 = "Elevated" })
		Utils.corner(card, UDim.new(0, 8))
		local cs = Utils.stroke(card, theme:get("Stroke"), 1)
		theme:register(cs, { Color = "Stroke" })

		-- left accent strip tinted by type
		local strip = Utils.create("Frame", {
			Name = "Strip",
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = theme:get(accentToken),
			BorderSizePixel = 0,
			Parent = card,
		})
		theme:register(strip, { BackgroundColor3 = accentToken })

		local inner = Utils.create("Frame", {
			Name = "Inner",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		})
		Utils.padding(inner, { top = 9, bottom = 9, left = 14, right = 30 })
		Utils.layout(inner, Enum.FillDirection.Vertical, 3)

		local title = Utils.create("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			Text = options.Title or "Notification",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = inner,
		})
		theme:register(title, { TextColor3 = "TextPrimary" })

		if options.Content and options.Content ~= "" then
			local body = Utils.create("TextLabel", {
				Name = "Content",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = options.Content,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 2,
				Parent = inner,
			})
			theme:register(body, { TextColor3 = "TextMuted" })
		end

		local close = Utils.create("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Text = "×",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Parent = card,
		})
		theme:register(close, { TextColor3 = "TextMuted" })

		local toast = { card = card, height = 0 }
		close.MouseButton1Click:Connect(function()
			self:_dismiss(toast)
		end)

		-- Measure height once laid out, then slot in + drift/fade in.
		task.defer(function()
			if not card.Parent then
				return
			end
			toast.height = card.AbsoluteSize.Y
			table.insert(self._active, toast)
			self:_reflow()
			Animations.tween(card, "Notify", { GroupTransparency = 0 })
		end)

		local duration = options.Duration or 4
		if duration > 0 then
			task.delay(duration, function()
				self:_dismiss(toast)
			end)
		end

		return toast
	end

	function Notifications:Destroy()
		if self._container then
			self._container:Destroy()
		end
	end

	return Notifications
end
