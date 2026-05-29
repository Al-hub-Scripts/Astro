--[[ Search — global search across every tab/group/element. Filters the prebuilt
     window.searchIndex on each keystroke (no tree rebuild). Selecting a result
     navigates there (switch tab + group) and pulses the matched element. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	local Search = {}
	Search.__index = Search

	local PANEL_W = 280
	local PANEL_H = 270
	local ROW_H = 40
	local MAX_RESULTS = 60

	function Search.new(ctx)
		local self = setmetatable({}, Search)
		self.window = ctx.window
		self.theme = ctx.theme
		self._open = false

		local theme = ctx.theme
		local topH = theme:size("TopBarHeight")

		local panel = Utils.create("CanvasGroup", {
			Name = "SearchPanel",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, topH + 6),
			Size = UDim2.fromOffset(PANEL_W, 0),
			BackgroundColor3 = theme:get("Elevated"),
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 60,
			Parent = ctx.parent,
		})
		theme:register(panel, { BackgroundColor3 = "Elevated" })
		Utils.corner(panel, UDim.new(0, 10))
		local ps = Utils.stroke(panel, theme:get("Stroke"), 1)
		theme:register(ps, { Color = "Stroke" })
		self._panel = panel

		local field = Utils.create("Frame", {
			Name = "Field",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 30),
			BackgroundColor3 = theme:get("Background"),
			BorderSizePixel = 0,
			Parent = panel,
		})
		theme:register(field, { BackgroundColor3 = "Background" })
		Utils.corner(field, UDim.new(0, 6))

		local box = Utils.create("TextBox", {
			Name = "Box",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			PlaceholderText = "Search everything…",
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Parent = field,
		})
		theme:register(box, { TextColor3 = "TextPrimary", PlaceholderColor3 = "TextMuted" })
		Utils.padding(box, { left = 10, right = 10 })
		self._box = box

		local results = Utils.create("ScrollingFrame", {
			Name = "Results",
			Position = UDim2.fromOffset(6, 48),
			Size = UDim2.new(1, -12, 1, -54),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme:get("TextMuted"),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = panel,
		})
		Utils.layout(results, Enum.FillDirection.Vertical, 3)
		Utils.padding(results, { left = 4, right = 4, top = 2, bottom = 2 })
		self._results = results

		local empty = Utils.create("TextLabel", {
			Name = "Empty",
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundTransparency = 1,
			Text = "Type to search…",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			Parent = results,
		})
		theme:register(empty, { TextColor3 = "TextMuted" })
		self._empty = empty

		ctx.maid:give(box:GetPropertyChangedSignal("Text"):Connect(function()
			self:_filter(box.Text)
		end))
		ctx.maid:give(box.FocusLost:Connect(function(enter)
			if enter then
				-- jump to first result on Enter
				local first = self._firstResult
				if first then
					self:_choose(first)
				end
			end
		end))
		ctx.maid:give(panel)
		return self
	end

	function Search:_choose(entry)
		self.window:select(entry.tab, entry.group, entry.handle)
		self:close()
	end

	function Search:_clearRows()
		for _, child in ipairs(self._results:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	function Search:_filter(query)
		query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		self:_clearRows()
		self._firstResult = nil

		if query == "" then
			self._empty.Visible = true
			self._empty.Text = "Type to search…"
			return
		end

		local theme = self.theme
		local matches = 0
		for _, entry in ipairs(self.window.searchIndex) do
			if entry.name and tostring(entry.name):lower():find(query, 1, true) then
				matches = matches + 1
				if not self._firstResult then
					self._firstResult = entry
				end

				local row = Utils.create("TextButton", {
					Name = "Result",
					Size = UDim2.new(1, 0, 0, ROW_H),
					BackgroundColor3 = theme:get("ElevatedHover"),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = matches,
					Parent = self._results,
				})
				Utils.corner(row, UDim.new(0, 6))

				local name = Utils.create("TextLabel", {
					Position = UDim2.fromOffset(10, 5),
					Size = UDim2.new(1, -16, 0, 16),
					BackgroundTransparency = 1,
					Text = entry.name,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				theme:register(name, { TextColor3 = "TextPrimary" })

				local path = Utils.create("TextLabel", {
					Position = UDim2.fromOffset(10, 21),
					Size = UDim2.new(1, -16, 0, 12),
					BackgroundTransparency = 1,
					Text = (entry.tab._name or "?") .. "  ›  " .. (entry.group._name or "?"),
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				theme:register(path, { TextColor3 = "TextMuted" })

				row.MouseEnter:Connect(function()
					Animations.tween(row, "Hover", { BackgroundTransparency = 0.3 })
				end)
				row.MouseLeave:Connect(function()
					Animations.tween(row, "Hover", { BackgroundTransparency = 1 })
				end)
				row.MouseButton1Click:Connect(function()
					self:_choose(entry)
				end)

				if matches >= MAX_RESULTS then
					break
				end
			end
		end

		if matches == 0 then
			self._empty.Visible = true
			self._empty.Text = "No matches for \"" .. query .. "\""
		else
			self._empty.Visible = false
		end
	end

	function Search:onIndexChanged()
		if self._open then
			self:_filter(self._box.Text)
		end
	end

	function Search:open()
		if self._open then
			return
		end
		self._open = true
		self._panel.Visible = true
		self:_filter(self._box.Text)
		Animations.tween(self._panel, "Expand", { Size = UDim2.fromOffset(PANEL_W, PANEL_H) })
		Animations.tween(self._panel, "Expand", { GroupTransparency = 0 })
		task.defer(function()
			self._box:CaptureFocus()
		end)
	end

	function Search:close()
		if not self._open then
			return
		end
		self._open = false
		self._box:ReleaseFocus()
		Animations.tween(self._panel, "Expand", { GroupTransparency = 1 })
		local tw = Animations.tween(self._panel, "Expand", { Size = UDim2.fromOffset(PANEL_W, 0) })
		tw.Completed:Connect(function()
			if not self._open then
				self._panel.Visible = false
			end
		end)
	end

	function Search:toggle()
		if self._open then
			self:close()
		else
			self:open()
		end
	end

	return Search
end
