--[[ Keybind — click to enter a "press a key…" listening state, then routes the
     bound key through the shared Keybinds registry (one global listener, not a
     connection per bind). Backspace/Delete unbinds; Escape cancels. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	local function keyName(keycode)
		if not keycode or keycode == Enum.KeyCode.Unknown then
			return "None"
		end
		return keycode.Name
	end

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local base = Utils.element(theme, parent, { name = config.Name or "Keybind", labelWidth = 0.55 })
		local root, stroke = base.root, base.stroke
		root.Name = "Keybind"

		local current = config.Default
		local callback = config.Callback
		local listening = false
		local id -- unique registry key; assigned once the handle table exists

		local pill = Utils.create("TextButton", {
			Name = "KeyPill",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 84, 0, 24),
			BackgroundColor3 = theme:get("Background"),
			Text = keyName(current),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			AutoButtonColor = false,
			Parent = root,
		})
		theme:register(pill, { BackgroundColor3 = "Background", TextColor3 = "TextPrimary" })
		Utils.corner(pill, UDim.new(0, 6))
		local pillStroke = Utils.stroke(pill, theme:get("Stroke"), 1)
		theme:register(pillStroke, { Color = "Stroke" })

		Utils.hoverLift(theme, root, stroke, maid)
		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(pill, config.Tooltip)
		end

		local handle = { Instance = root, Name = config.Name or "Keybind", Type = "Keybind" }
		handle._highlightStroke = stroke
		id = handle -- unique registry key

		local function rebind(keycode)
			current = keycode
			pill.Text = keyName(current)
			if ctx.keybinds then
				if keycode and keycode ~= Enum.KeyCode.Unknown then
					ctx.keybinds:bind(id, keycode, function()
						if callback then
							task.spawn(callback)
						end
					end)
				else
					ctx.keybinds:unbind(id)
				end
			end
			-- Fired when the bound key changes (e.g. to rebind the window toggle).
			if config.OnChanged then
				task.spawn(config.OnChanged, keycode)
			end
		end

		-- initial bind
		if current and current ~= Enum.KeyCode.Unknown and ctx.keybinds then
			ctx.keybinds:bind(id, current, function()
				if callback then
					task.spawn(callback)
				end
			end)
		end

		local listenConn
		local function stopListening()
			listening = false
			if listenConn then
				listenConn:Disconnect()
				listenConn = nil
			end
			pill.Text = keyName(current)
			Animations.tween(pillStroke, "Hover", { Color = theme:get("Stroke"), Transparency = 0 })
		end

		maid:give(pill.MouseButton1Click:Connect(function()
			if listening then
				return
			end
			listening = true
			pill.Text = "..."
			Animations.tween(pillStroke, "Hover", { Color = theme:get("Accent"), Transparency = 0 })
			listenConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				local key = input.KeyCode
				if key == Enum.KeyCode.Escape then
					stopListening()
				elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
					rebind(nil)
					stopListening()
				else
					rebind(key)
					stopListening()
				end
			end)
			maid:give(listenConn)
		end))

		function handle:Set(keycode, skipCallback)
			rebind(keycode)
		end
		function handle:Get()
			return current
		end
		function handle:SetVisible(visible)
			root.Visible = visible and true or false
		end
		function handle:Destroy()
			if ctx.keybinds then
				ctx.keybinds:unbind(id)
			end
			root:Destroy()
		end
		return handle
	end
end
