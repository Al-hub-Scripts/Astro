--[[ Button — the whole row is the hit target. Soft press: a UIScale dip plus a
     gentle accent wash that fades out (cloud-soft, never a hard material flash). ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local base = Utils.element(theme, parent, { name = config.Name or "Button", labelWidth = 1 })
		local root, label, stroke = base.root, base.label, base.stroke
		root.Name = "Button"
		local scaler = Utils.scaler(root, 1)

		-- Accent wash overlay for the soft "ripple" feel.
		local wash = Utils.create("Frame", {
			Name = "Wash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme:get("Accent"),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = root,
		})
		theme:register(wash, { BackgroundColor3 = "Accent" })
		Utils.corner(wash, theme:size("ElementCorner"))

		-- A subtle trailing chevron hints "actionable".
		local chevron = Utils.create("TextLabel", {
			Name = "Chevron",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(10, 16),
			BackgroundTransparency = 1,
			Text = "›",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Parent = root,
		})
		theme:register(chevron, { TextColor3 = "TextMuted" })

		local hit = Utils.create("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = root,
		})

		Utils.hoverLift(theme, root, stroke, maid)
		maid:give(hit.MouseEnter:Connect(function()
			Animations.tween(chevron, "Hover", { TextColor3 = theme:get("Accent"), Position = UDim2.new(1, -9, 0.5, 0) })
		end))
		maid:give(hit.MouseLeave:Connect(function()
			Animations.tween(chevron, "Hover", { TextColor3 = theme:get("TextMuted"), Position = UDim2.new(1, -12, 0.5, 0) })
		end))

		local callback = config.Callback
		local function fire()
			-- soft press dip + accent wash in then out
			Animations.tween(scaler, "Press", { Scale = 0.97 })
			wash.BackgroundTransparency = 0.82
			Animations.tween(wash, "Expand", { BackgroundTransparency = 1 })
			task.delay(0.09, function()
				Animations.tween(scaler, "Press", { Scale = 1 })
			end)
			if callback then
				task.spawn(callback)
			end
		end
		maid:give(hit.MouseButton1Click:Connect(fire))

		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(hit, config.Tooltip)
		end

		local handle = { Instance = root, Name = config.Name or "Button", Type = "Button" }
		handle._highlightStroke = stroke
		function handle:Set(fn)
			if type(fn) == "function" then
				callback = fn
			end
		end
		function handle:Get()
			return callback
		end
		function handle:Fire()
			fire()
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
