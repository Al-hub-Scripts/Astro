--[[ Dropdown — single or multi select. Soft inline unfold: the row's own height
     eases open to reveal a (scrolling, if long) option list, so the page's
     AutomaticCanvasSize just flows around it. Multi shows filled checkboxes. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")

	local OPTION_H = 30
	local MAX_VISIBLE = 5

	return function(ctx, parent, config)
		local theme = ctx.theme
		local maid = ctx.maid

		local multi = config.Multi == true
		local options = config.Options or {}
		local callback = config.Callback

		-- selection state
		local selectedSet = {} -- [optionName] = true
		local function selectionArray()
			local arr = {}
			for _, opt in ipairs(options) do
				if selectedSet[opt] then
					table.insert(arr, opt)
				end
			end
			return arr
		end

		local base = Utils.element(theme, parent, { name = config.Name or "Dropdown", labelWidth = 0.4 })
		local root, stroke = base.root, base.stroke
		root.Name = "Dropdown"
		root.ClipsDescendants = true
		root.AutomaticSize = Enum.AutomaticSize.None

		local header = Utils.create("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, theme:size("ElementHeight")),
			BackgroundTransparency = 1,
			Parent = root,
		})
		base.label.Parent = header

		local chevron = Utils.create("TextLabel", {
			Name = "Chevron",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(10, 16),
			BackgroundTransparency = 1,
			Text = "›",
			Rotation = 90, -- points down when collapsed
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Parent = header,
		})
		theme:register(chevron, { TextColor3 = "TextMuted" })

		local valueText = Utils.create("TextLabel", {
			Name = "ValueText",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -30, 0.5, 0),
			Size = UDim2.new(0.5, -30, 1, 0),
			BackgroundTransparency = 1,
			Text = config.Placeholder or "...",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		theme:register(valueText, { TextColor3 = "TextMuted" })

		-- Options area (revealed on expand).
		local listScroll = Utils.create("ScrollingFrame", {
			Name = "Options",
			Position = UDim2.new(0, 0, 0, theme:size("ElementHeight")),
			Size = UDim2.new(1, 0, 1, -theme:size("ElementHeight")),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme:get("TextMuted"),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = root,
		})
		Utils.padding(listScroll, { top = 2, bottom = 6, left = 8, right = 8 })
		Utils.layout(listScroll, Enum.FillDirection.Vertical, 3)

		local optionRows = {}

		local function refreshHeader()
			local arr = selectionArray()
			if #arr == 0 then
				valueText.Text = config.Placeholder or "..."
			elseif multi then
				valueText.Text = #arr == 1 and arr[1] or (#arr .. " selected")
			else
				valueText.Text = arr[1]
			end
		end

		local function refreshRows(animate)
			for opt, row in pairs(optionRows) do
				local on = selectedSet[opt] == true
				local textColor = on and theme:get("Accent") or theme:get("TextMuted")
				local boxColor = on and theme:get("Accent") or theme:get("Background")
				if animate == false then
					row.label.TextColor3 = textColor
					row.box.BackgroundColor3 = boxColor
					row.tick.BackgroundTransparency = on and 0 or 1
				else
					Animations.tween(row.label, "Toggle", { TextColor3 = textColor })
					Animations.tween(row.box, "Toggle", { BackgroundColor3 = boxColor })
					Animations.tween(row.tick, "Toggle", { BackgroundTransparency = on and 0 or 1 })
				end
			end
		end

		local expanded = false
		local function collapsedHeight()
			return theme:size("ElementHeight")
		end
		local function expandedHeight()
			local visible = math.min(#options, MAX_VISIBLE)
			return theme:size("ElementHeight") + visible * (OPTION_H + 3) + 8
		end
		local function setExpanded(state)
			expanded = state
			Animations.tween(root, "Expand", { Size = UDim2.new(1, 0, 0, state and expandedHeight() or collapsedHeight()) })
			Animations.tween(chevron, "Expand", { Rotation = state and 270 or 90 })
		end

		local handle = { Instance = root, Name = config.Name or "Dropdown", Type = "Dropdown" }
		handle._highlightStroke = stroke

		local function commit(skipCallback)
			refreshHeader()
			refreshRows(true)
			if not skipCallback and callback then
				task.spawn(callback, multi and selectionArray() or selectionArray()[1])
			end
		end

		local function choose(opt)
			if multi then
				selectedSet[opt] = not selectedSet[opt] or nil
				commit(false)
			else
				for k in pairs(selectedSet) do
					selectedSet[k] = nil
				end
				selectedSet[opt] = true
				commit(false)
				setExpanded(false)
			end
		end

		local function buildOption(opt)
			local row = Utils.create("TextButton", {
				Name = "Opt_" .. tostring(opt),
				Size = UDim2.new(1, 0, 0, OPTION_H),
				BackgroundColor3 = theme:get("Background"),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = listScroll,
			})
			Utils.corner(row, UDim.new(0, 6))
			local box = Utils.create("Frame", {
				Name = "Box",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = theme:get("Background"),
				BorderSizePixel = 0,
				Parent = row,
			})
			Utils.corner(box, UDim.new(0, 4))
			local boxStroke = Utils.stroke(box, theme:get("Stroke"), 1)
			theme:register(boxStroke, { Color = "Stroke" })
			local tick = Utils.create("Frame", {
				Name = "Tick",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = theme:get("TextOnAccent"),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = box,
			})
			theme:register(tick, { BackgroundColor3 = "TextOnAccent" })
			Utils.corner(tick, UDim.new(0, 2))
			local label = Utils.create("TextLabel", {
				Name = "Label",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 30, 0.5, 0),
				Size = UDim2.new(1, -38, 1, 0),
				BackgroundTransparency = 1,
				Text = tostring(opt),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})

			optionRows[opt] = { row = row, label = label, box = box, tick = tick }
			maid:give(row.MouseEnter:Connect(function()
				Animations.tween(row, "Hover", { BackgroundTransparency = 0.4 })
			end))
			maid:give(row.MouseLeave:Connect(function()
				Animations.tween(row, "Hover", { BackgroundTransparency = 1 })
			end))
			maid:give(row.MouseButton1Click:Connect(function()
				choose(opt)
			end))
		end

		for _, opt in ipairs(options) do
			buildOption(opt)
		end

		-- header click toggles expansion
		local hit = Utils.create("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = header,
		})
		Utils.hoverLift(theme, root, stroke, maid)
		maid:give(hit.MouseButton1Click:Connect(function()
			setExpanded(not expanded)
		end))
		if config.Tooltip and ctx.tooltip then
			ctx.tooltip:attach(hit, config.Tooltip)
		end

		-- defaults
		if config.Default ~= nil then
			if multi and type(config.Default) == "table" then
				for _, opt in ipairs(config.Default) do
					selectedSet[opt] = true
				end
			elseif not multi then
				selectedSet[config.Default] = true
			end
		end
		refreshHeader()
		refreshRows(false)

		function handle:Set(value, skipCallback)
			for k in pairs(selectedSet) do
				selectedSet[k] = nil
			end
			if multi and type(value) == "table" then
				for _, opt in ipairs(value) do
					selectedSet[opt] = true
				end
			elseif value ~= nil then
				selectedSet[value] = true
			end
			commit(skipCallback)
		end
		function handle:Get()
			return multi and selectionArray() or selectionArray()[1]
		end
		function handle:SetOptions(newOptions)
			options = newOptions or {}
			for _, row in pairs(optionRows) do
				row.row:Destroy()
			end
			optionRows = {}
			for k in pairs(selectedSet) do
				selectedSet[k] = nil
			end
			for _, opt in ipairs(options) do
				buildOption(opt)
			end
			refreshHeader()
			refreshRows(false)
			if expanded then
				setExpanded(true)
			end
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
