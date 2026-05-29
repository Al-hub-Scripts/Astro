--[[
    Library.lua — core orchestration. Builds the Window shell (panel, shadow,
    top bar, sidebar, content, footer), the navigation model, and wires in
    every System. Exposes the public consumer API.

    Navigation model (spec §4 — note the inversion vs the reference labels):
      LEFT SIDEBAR = TABS   (top-level categories; primary nav)
      TOP BAR      = GROUPS (belong to the active tab; animated accent underline)
      CONTENT      = elements of the active group
]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local Theme = require("Theme")

	local Dragger = require("Systems/Dragger")
	local Notifications = require("Systems/Notifications")
	local ConfigManager = require("Systems/ConfigManager")
	local Search = require("Systems/Search")
	local Keybinds = require("Systems/Keybinds")
	local Tooltip = require("Systems/Tooltip")

	-- Component constructors. Each is `function(ctx, parent, config) -> handle`.
	local Components = {
		Button = require("Components/Button"),
		Toggle = require("Components/Toggle"),
		Slider = require("Components/Slider"),
		Dropdown = require("Components/Dropdown"),
		Textbox = require("Components/Textbox"),
		Keybind = require("Components/Keybind"),
		ColorPicker = require("Components/ColorPicker"),
		Label = require("Components/Label"),
		Paragraph = require("Components/Paragraph"),
		Section = require("Components/Section"),
	}

	local create = Utils.create
	local SHADOW_ASSET = "rbxassetid://6014261993" -- soft radial glow → fake elevation

	-- ======================================================================
	-- GROUP — a horizontal top-bar item owning a scrollable content page.
	-- ======================================================================
	local Group = {}
	Group.__index = Group

	-- Internal: mount a component into this group's content, then wire it into
	-- the config (flags) and search index. This is the single choke-point so
	-- those systems never get bypassed.
	function Group:_mount(kind, config)
		config = config or {}
		local ctor = Components[kind]
		local handle = ctor(self._ctx, self._scroll, config)
		handle.Type = handle.Type or kind
		handle.Name = handle.Name or config.Name or kind

		-- Keep stable ordering in the list layout.
		self._order = self._order + 1
		if handle.Instance then
			handle.Instance.LayoutOrder = self._order
		end

		-- Config flag registration (no-op if no flag or no file API).
		if config.Flag and self._ctx.config then
			self._ctx.config:register(config.Flag, handle)
		end

		-- Search index: every named element becomes findable.
		if handle.Name and handle.Instance then
			table.insert(self._window.searchIndex, {
				tab = self._tab,
				group = self,
				handle = handle,
				name = handle.Name,
			})
			if self._window.search then
				self._window.search:onIndexChanged()
			end
		end

		return handle
	end

	function Group:Button(config)
		return self:_mount("Button", config)
	end
	function Group:Toggle(config)
		return self:_mount("Toggle", config)
	end
	function Group:Slider(config)
		return self:_mount("Slider", config)
	end
	function Group:Dropdown(config)
		return self:_mount("Dropdown", config)
	end
	function Group:Textbox(config)
		return self:_mount("Textbox", config)
	end
	function Group:Keybind(config)
		return self:_mount("Keybind", config)
	end
	function Group:ColorPicker(config)
		return self:_mount("ColorPicker", config)
	end
	function Group:Label(text)
		return self:_mount("Label", { Text = type(text) == "table" and text.Text or text })
	end
	function Group:Paragraph(config)
		return self:_mount("Paragraph", config)
	end
	function Group:Section(config)
		return self:_mount("Section", type(config) == "string" and { Name = config } or config)
	end

	-- ======================================================================
	-- TAB — a left-sidebar row owning a set of groups + its own top nav bar.
	-- ======================================================================
	local Tab = {}
	Tab.__index = Tab

	function Tab:CreateGroup(config)
		config = config or {}
		local window = self._window
		local theme = window.theme

		local group = setmetatable({}, Group)
		group._window = window
		group._tab = self
		group._ctx = window._ctx
		group._order = 0
		group._name = config.Name or ("Group " .. (#self._groups + 1))

		-- Content page: a CanvasGroup gives us a real cross-fade (GroupTransparency)
		-- and clips its own scroll. Hidden until activated.
		local canvas = create("CanvasGroup", {
			Name = "Page_" .. group._name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			Parent = window._contentContainer,
		})
		local scroll = create("ScrollingFrame", {
			Name = "Scroll",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme:get("TextMuted"),
			ScrollBarImageTransparency = 0.4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = canvas,
		})
		Utils.padding(scroll, {
			top = theme:size("ContentPadding"),
			bottom = theme:size("ContentPadding"),
			left = theme:size("ContentPadding"),
			right = theme:size("ContentPadding") + 4, -- room for the scrollbar
		})
		Utils.layout(scroll, Enum.FillDirection.Vertical, theme:size("ElementSpacing"))

		group._canvas = canvas
		group._scroll = scroll

		-- Top-bar nav button for this group (lives inside the tab's nav row).
		local navButton = create("TextButton", {
			Name = "GroupNav_" .. group._name,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = group._name,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = false,
			Parent = self._navContainer,
		})
		theme:register(navButton, { TextColor3 = "TextMuted" })
		Utils.padding(navButton, { left = 4, right = 4 })
		group._navButton = navButton

		navButton.MouseButton1Click:Connect(function()
			self:_setGroup(group)
		end)
		navButton.MouseEnter:Connect(function()
			if self._activeGroup ~= group then
				Animations.tween(navButton, "Hover", { TextColor3 = theme:get("TextPrimary") })
			end
		end)
		navButton.MouseLeave:Connect(function()
			if self._activeGroup ~= group then
				Animations.tween(navButton, "Hover", { TextColor3 = theme:get("TextMuted") })
			end
		end)

		table.insert(self._groups, group)

		-- First group of a tab becomes its default active group.
		if not self._activeGroup then
			self._activeGroup = group
			if self._window._activeTab == self then
				canvas.Visible = true
				canvas.GroupTransparency = 0
				navButton.TextColor3 = theme:get("Accent")
				window:_moveUnderlineTo(navButton)
			end
		end

		return group
	end

	-- Switch the visible content page within this tab + glide the underline.
	function Tab:_setGroup(group, skipAnim)
		if self._activeGroup == group and not skipAnim then
			return
		end
		local theme = self._window.theme
		local previous = self._activeGroup
		self._activeGroup = group

		if previous and previous ~= group then
			Animations.tween(previous._navButton, "Underline", { TextColor3 = theme:get("TextMuted") })
			local out = previous._canvas
			Animations.tween(out, "TabSwitch", { GroupTransparency = 1, Position = UDim2.fromOffset(0, -10) })
			task.delay(0.18, function()
				if self._activeGroup ~= previous then
					out.Visible = false
				end
			end)
		end

		group._navButton.TextColor3 = theme:get("Accent")
		local inc = group._canvas
		inc.Visible = true
		inc.GroupTransparency = 1
		inc.Position = UDim2.fromOffset(0, 12) -- drift up into place
		Animations.tween(inc, "TabSwitch", { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })

		self._window:_moveUnderlineTo(group._navButton)
	end

	-- ======================================================================
	-- WINDOW
	-- ======================================================================
	local Window = {}
	Window.__index = Window

	function Window:CreateTab(config)
		config = config or {}
		local theme = self.theme

		-- Sidebar row.
		local row = create("TextButton", {
			Name = "Tab_" .. (config.Name or "?"),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = self._sidebarList,
		})
		-- Soft pill behind the row content (fades in on hover / active).
		local pill = create("Frame", {
			Name = "Pill",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = row,
		})
		theme:register(pill, { BackgroundColor3 = "ElevatedHover" })
		Utils.corner(pill, theme:size("ElementCorner"))
		-- Left accent indicator bar (height grows when active).
		local indicator = create("Frame", {
			Name = "Indicator",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 0),
			BorderSizePixel = 0,
			Parent = row,
		})
		theme:register(indicator, { BackgroundColor3 = "Accent" })
		Utils.corner(indicator, UDim.new(1, 0))

		local hasIcon = config.Icon ~= nil
		if hasIcon then
			local icon = create("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = config.Icon,
				Parent = row,
			})
			theme:register(icon, { ImageColor3 = "TextMuted" })
			row:SetAttribute("HasIcon", true)
		end

		local label = create("TextLabel", {
			Name = "Label",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, hasIcon and 36 or 14, 0.5, 0),
			Size = UDim2.new(1, -(hasIcon and 44 or 22), 1, 0),
			BackgroundTransparency = 1,
			Text = config.Name or "Tab",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		theme:register(label, { TextColor3 = "TextMuted" })

		-- Per-tab top nav container (holds this tab's group buttons).
		local navContainer = create("Frame", {
			Name = "Nav_" .. (config.Name or "?"),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = self._navHolder,
		})
		Utils.layout(navContainer, Enum.FillDirection.Horizontal, 16, {
			v = Enum.VerticalAlignment.Center,
		})

		local tab = setmetatable({}, Tab)
		tab._window = self
		tab._groups = {}
		tab._activeGroup = nil
		tab._row = row
		tab._pill = pill
		tab._indicator = indicator
		tab._label = label
		tab._icon = row:FindFirstChild("Icon")
		tab._navContainer = navContainer
		tab._name = config.Name or "Tab"

		row.MouseButton1Click:Connect(function()
			self:_setTab(tab)
		end)
		row.MouseEnter:Connect(function()
			if self._activeTab ~= tab then
				Animations.tween(pill, "Hover", { BackgroundTransparency = 0.55 })
			end
		end)
		row.MouseLeave:Connect(function()
			if self._activeTab ~= tab then
				Animations.tween(pill, "Hover", { BackgroundTransparency = 1 })
			end
		end)

		table.insert(self._tabs, tab)

		-- First tab auto-activates.
		if not self._activeTab then
			self:_setTab(tab, true)
		end

		return tab
	end

	-- Optional muted uppercase header to group sidebar rows (spec §4).
	function Window:Section(name)
		local theme = self.theme
		local header = create("TextLabel", {
			Name = "SidebarSection",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = string.upper(name or "Section"),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = self._sidebarList,
		})
		theme:register(header, { TextColor3 = "TextMuted" })
		Utils.padding(header, { left = 6, top = 8 })
		return header
	end

	function Window:_setTab(tab, skipAnim)
		if self._activeTab == tab and not skipAnim then
			return
		end
		local theme = self.theme
		local previous = self._activeTab
		self._activeTab = tab

		-- Restyle sidebar rows.
		if previous and previous ~= tab then
			Animations.tween(previous._pill, "TabSwitch", { BackgroundTransparency = 1 })
			Animations.tween(previous._label, "TabSwitch", { TextColor3 = theme:get("TextMuted") })
			Animations.tween(previous._indicator, "TabSwitch", { Size = UDim2.new(0, 3, 0, 0) })
			if previous._icon then
				Animations.tween(previous._icon, "TabSwitch", { ImageColor3 = theme:get("TextMuted") })
			end
			previous._navContainer.Visible = false
			if previous._activeGroup then
				previous._activeGroup._canvas.Visible = false
			end
		end

		Animations.tween(tab._pill, "TabSwitch", { BackgroundTransparency = 0 })
		Animations.tween(tab._label, "TabSwitch", { TextColor3 = theme:get("TextPrimary") })
		Animations.tween(tab._indicator, "TabSwitch", { Size = UDim2.new(0, 3, 0.55, 0) })
		if tab._icon then
			Animations.tween(tab._icon, "TabSwitch", { ImageColor3 = theme:get("Accent") })
		end
		tab._navContainer.Visible = true

		-- Show the tab's active group (default first) with a soft drift-in.
		local group = tab._activeGroup or tab._groups[1]
		if group then
			tab._activeGroup = nil -- force _setGroup to run the in-animation
			tab:_setGroup(group, true)
		else
			self:_moveUnderlineTo(nil)
		end
	end

	-- Glide the single shared underline to a group nav button. Computed from
	-- absolute positions so it's correct regardless of layout; deferred a frame
	-- so AbsolutePosition is valid right after creation.
	function Window:_moveUnderlineTo(button)
		local underline = self._underline
		if not button then
			Animations.tween(underline, "Underline", { Size = UDim2.new(0, 0, 0, 2) })
			return
		end
		task.defer(function()
			if not button or not button.Parent then
				return
			end
			local holder = self._navHolder
			local localX = button.AbsolutePosition.X - holder.AbsolutePosition.X
			Animations.tween(underline, "Underline", {
				Position = UDim2.new(0, localX, 1, -1),
				Size = UDim2.new(0, button.AbsoluteSize.X, 0, 2),
			})
		end)
	end

	-- Pulse a soft accent glow on an element (used by search navigation).
	function Window:_highlight(handle)
		if not handle or not handle.Instance then
			return
		end
		local stroke = handle._highlightStroke or handle.Instance:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Utils.stroke(handle.Instance, self.theme:get("Accent"), 1, 1)
		end
		Animations.pulse(stroke, self.theme:get("Accent"), stroke.Transparency)
		-- Make sure it's scrolled into view.
		task.defer(function()
			local scroll = handle.Instance:FindFirstAncestorWhichIsA("ScrollingFrame")
			if scroll then
				local y = handle.Instance.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
				Animations.tween(scroll, "TabSwitch", { CanvasPosition = Vector2.new(0, math.max(0, y - 20)) })
			end
		end)
	end

	-- Used by Search to jump to a result.
	function Window:select(tab, group, handle)
		if tab and self._activeTab ~= tab then
			self:_setTab(tab)
		end
		if group and tab then
			tab:_setGroup(group)
		end
		if handle then
			task.delay(0.15, function()
				self:_highlight(handle)
			end)
		end
	end

	-- ---------------- visibility / lifecycle ----------------
	function Window:Show(skipAnim)
		if self._destroyed then
			return
		end
		self._root.Visible = true
		self._visible = true
		if skipAnim then
			self._window.GroupTransparency = 0
			self._scale.Scale = 1
			self._shadow.ImageTransparency = 0.45
			return
		end
		self._window.GroupTransparency = 1
		self._scale.Scale = 0.96
		self._shadow.ImageTransparency = 1
		Animations.tween(self._window, "WindowOpen", { GroupTransparency = 0 })
		Animations.tween(self._scale, "WindowOpen", { Scale = 1 })
		Animations.tween(self._shadow, "WindowOpen", { ImageTransparency = 0.45 })
	end

	function Window:Hide()
		if self._destroyed or not self._visible then
			return
		end
		self._visible = false
		Animations.tween(self._window, "WindowClose", { GroupTransparency = 1 })
		Animations.tween(self._shadow, "WindowClose", { ImageTransparency = 1 })
		local tw = Animations.tween(self._scale, "WindowClose", { Scale = 0.96 })
		tw.Completed:Connect(function()
			if not self._visible then
				self._root.Visible = false
			end
		end)
	end

	function Window:Toggle()
		if self._visible then
			self:Hide()
		else
			self:Show()
		end
	end

	function Window:_setMinimized(state)
		self._minimized = state
		local size = state and UDim2.fromOffset(self.theme:size("WindowSize").X.Offset, self.theme:size("TopBarHeight"))
			or self.theme:size("WindowSize")
		Animations.tween(self._root, "Expand", { Size = size })
	end

	function Window:Minimize()
		self:_setMinimized(not self._minimized)
	end

	function Window:Notify(options)
		if self._notifier then
			self._notifier:Notify(options)
		end
	end

	function Window:SetTheme(name, animate)
		local ok = self.theme:set(name, animate)
		if ok then
			self:_refreshStates()
		end
		return ok
	end

	-- Re-apply stateful (active/hover) colors after a theme swap, since those
	-- aren't part of the theme auto-registry.
	function Window:_refreshStates()
		local theme = self.theme
		for _, tab in ipairs(self._tabs) do
			local active = self._activeTab == tab
			tab._label.TextColor3 = active and theme:get("TextPrimary") or theme:get("TextMuted")
			tab._pill.BackgroundTransparency = active and 0 or 1
			if tab._icon then
				tab._icon.ImageColor3 = active and theme:get("Accent") or theme:get("TextMuted")
			end
			for _, group in ipairs(tab._groups) do
				local gActive = tab._activeGroup == group
				group._navButton.TextColor3 = gActive and theme:get("Accent") or theme:get("TextMuted")
			end
		end
	end

	function Window:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		if self._config then
			self._config:unbindAll()
		end
		self.maid:clean() -- disconnects everything + destroys ScreenGui & systems
	end

	-- ======================================================================
	-- Window construction
	-- ======================================================================
	local function buildWindow(library, config)
		config = config or {}
		local maid = Utils.Maid.new()
		local theme = Theme.new(config.Theme)

		local self = setmetatable({}, Window)
		self.theme = theme
		self.maid = maid
		self._tabs = {}
		self._activeTab = nil
		self._visible = true
		self._minimized = false
		self.searchIndex = {}

		-- ScreenGui (safely parented).
		local gui = create("ScreenGui", {
			Name = "Astrophysics_" .. tostring(math.random(1000, 9999)),
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			IgnoreGuiInset = true,
			DisplayOrder = 9999,
		})
		Utils.parentGui(gui)
		maid:give(gui)
		self.gui = gui

		-- root (drag/scale/minimize target — NOT clipped so the shadow shows).
		local root = create("Frame", {
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = theme:size("WindowSize"),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		local scale = Utils.scaler(root, 0.96)
		self._root = root
		self._scale = scale

		-- Soft elevation shadow behind the panel.
		local shadow = create("ImageLabel", {
			Name = "Shadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 70, 1, 70),
			BackgroundTransparency = 1,
			Image = SHADOW_ASSET,
			ImageColor3 = theme:get("Shadow"),
			ImageTransparency = 1,
			ZIndex = 0,
			Parent = root,
		})
		self._shadow = shadow

		-- window: a CanvasGroup so open/close fades the entire panel at once
		-- (GroupTransparency) and clips its own content.
		local window = create("CanvasGroup", {
			Name = "Window",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme:get("Background"),
			GroupTransparency = 1,
			ZIndex = 1,
			Parent = root,
		})
		Utils.corner(window, theme:size("CornerRadius"))
		local winStroke = Utils.stroke(window, theme:get("Stroke"), theme:size("StrokeThickness"))
		theme:register(window, { BackgroundColor3 = "Background" })
		theme:register(winStroke, { Color = "Stroke" })
		self._window = window

		local sidebarFrac = theme:size("SidebarWidth")
		local topH = theme:size("TopBarHeight")
		local footH = theme:size("FooterHeight")

		-- ---------- TOP BAR (drag handle) ----------
		local topbar = create("Frame", {
			Name = "TopBar",
			Size = UDim2.new(1, 0, 0, topH),
			BackgroundTransparency = 1,
			Active = true, -- reliably captures drag on empty areas
			Parent = window,
		})
		self._topbar = topbar

		-- Wordmark "Astro" + accent "physics" + subtitle, in the sidebar column.
		local brand = create("Frame", {
			Name = "Brand",
			Size = UDim2.new(sidebarFrac, 0, 1, 0),
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utils.padding(brand, { left = 14 })
		local titleRow = create("Frame", {
			Name = "TitleRow",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 0.5, 2),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Parent = brand,
		})
		Utils.layout(titleRow, Enum.FillDirection.Horizontal, 0)
		local title1 = create("TextLabel", {
			Name = "Title1",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = config.Title or "Astro",
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleRow,
		})
		theme:register(title1, { TextColor3 = "TextPrimary" })
		local title2 = create("TextLabel", {
			Name = "Title2",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = config.TitleAccent or "physics",
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleRow,
		})
		theme:register(title2, { TextColor3 = "Accent" })
		if config.Subtitle then
			local subtitle = create("TextLabel", {
				Name = "Subtitle",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 1, 0.5, 4),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 12),
				BackgroundTransparency = 1,
				Text = config.Subtitle,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = brand,
			})
			theme:register(subtitle, { TextColor3 = "TextMuted" })
		end

		-- Control cluster (right): search, minimize, close.
		local controls = create("Frame", {
			Name = "Controls",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 92, 0, 26),
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utils.layout(controls, Enum.FillDirection.Horizontal, 6, {
			h = Enum.HorizontalAlignment.Right,
			v = Enum.VerticalAlignment.Center,
		})

		-- Build a 26x26 icon button with a frame-drawn glyph (no asset deps).
		local function controlButton(name, drawer, order)
			local btn = create("TextButton", {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.fromOffset(26, 26),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
			})
			theme:register(btn, { BackgroundColor3 = "ElevatedHover" })
			Utils.corner(btn, UDim.new(0, 6))
			local glyph = create("Frame", {
				Name = "Glyph",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Parent = btn,
			})
			drawer(glyph)
			btn.MouseEnter:Connect(function()
				Animations.tween(btn, "Hover", { BackgroundTransparency = 0.35 })
			end)
			btn.MouseLeave:Connect(function()
				Animations.tween(btn, "Hover", { BackgroundTransparency = 1 })
			end)
			btn.Parent = controls
			return btn
		end

		local function bar(parent, w, h, rot)
			local f = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(w, h),
				Rotation = rot or 0,
				BorderSizePixel = 0,
				Parent = parent,
			})
			theme:register(f, { BackgroundColor3 = "TextPrimary" })
			Utils.corner(f, UDim.new(1, 0))
			return f
		end

		local searchBtn = controlButton("Search", function(glyph)
			local ring = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, -1, 0.5, -1),
				Size = UDim2.fromOffset(9, 9),
				BackgroundTransparency = 1,
				Parent = glyph,
			})
			Utils.corner(ring, UDim.new(1, 0))
			local rs = Utils.stroke(ring, theme:get("TextPrimary"), 1.5)
			theme:register(rs, { Color = "TextPrimary" })
			local handle = bar(glyph, 5, 1.6, 45)
			handle.Position = UDim2.new(0.5, 4, 0.5, 4)
		end, 1)

		local minBtn = controlButton("Minimize", function(glyph)
			bar(glyph, 12, 2, 0).Position = UDim2.fromScale(0.5, 0.62)
		end, 2)

		local closeBtn = controlButton("Close", function(glyph)
			bar(glyph, 13, 1.8, 45)
			bar(glyph, 13, 1.8, -45)
		end, 3)

		closeBtn.MouseButton1Click:Connect(function()
			self:Hide()
		end)
		minBtn.MouseButton1Click:Connect(function()
			self:Minimize()
		end)
		-- Close turns red on hover to read as destructive-ish.
		closeBtn.MouseEnter:Connect(function()
			for _, f in ipairs(closeBtn.Glyph:GetChildren()) do
				if f:IsA("Frame") then
					Animations.tween(f, "Hover", { BackgroundColor3 = theme:get("Negative") })
				end
			end
		end)
		closeBtn.MouseLeave:Connect(function()
			for _, f in ipairs(closeBtn.Glyph:GetChildren()) do
				if f:IsA("Frame") then
					Animations.tween(f, "Hover", { BackgroundColor3 = theme:get("TextPrimary") })
				end
			end
		end)

		-- Top-bar group nav holder (between brand and controls).
		local navHolder = create("Frame", {
			Name = "NavHolder",
			Position = UDim2.new(sidebarFrac, 4, 0, 0),
			Size = UDim2.new(1 - sidebarFrac, -(92 + 14), 1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = topbar,
		})
		self._navHolder = navHolder
		local underline = create("Frame", {
			Name = "Underline",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(0, 0, 0, 2),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = navHolder,
		})
		theme:register(underline, { BackgroundColor3 = "Accent" })
		Utils.corner(underline, UDim.new(1, 0))
		self._underline = underline

		-- Divider line under the top bar.
		local topDivider = create("Frame", {
			Name = "TopDivider",
			Position = UDim2.new(0, 0, 0, topH),
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			Parent = window,
		})
		theme:register(topDivider, { BackgroundColor3 = "Stroke" })

		-- ---------- BODY ----------
		local body = create("Frame", {
			Name = "Body",
			Position = UDim2.new(0, 0, 0, topH + 1),
			Size = UDim2.new(1, 0, 1, -(topH + 1 + footH)),
			BackgroundTransparency = 1,
			Parent = window,
		})

		local sidebar = create("Frame", {
			Name = "Sidebar",
			Size = UDim2.new(sidebarFrac, 0, 1, 0),
			BorderSizePixel = 0,
			Parent = body,
		})
		theme:register(sidebar, { BackgroundColor3 = "SidebarBg" })
		local sidebarList = create("ScrollingFrame", {
			Name = "TabList",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = sidebar,
		})
		Utils.padding(sidebarList, { top = 10, bottom = 10, left = 8, right = 8 })
		Utils.layout(sidebarList, Enum.FillDirection.Vertical, 4)
		self._sidebarList = sidebarList

		-- Vertical divider between sidebar and content.
		local vsep = create("Frame", {
			Name = "VSep",
			Position = UDim2.new(sidebarFrac, 0, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BorderSizePixel = 0,
			Parent = body,
		})
		theme:register(vsep, { BackgroundColor3 = "Stroke" })

		local contentContainer = create("Frame", {
			Name = "Content",
			Position = UDim2.new(sidebarFrac, 1, 0, 0),
			Size = UDim2.new(1 - sidebarFrac, -1, 1, 0),
			BackgroundTransparency = 1,
			Parent = body,
		})
		self._contentContainer = contentContainer

		-- ---------- FOOTER ----------
		local footer = create("Frame", {
			Name = "Footer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, footH),
			BorderSizePixel = 0,
			Parent = window,
		})
		theme:register(footer, { BackgroundColor3 = "SidebarBg" })
		local footDivider = create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			Parent = footer,
		})
		theme:register(footDivider, { BackgroundColor3 = "Stroke" })
		local status = create("TextLabel", {
			Name = "Status",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.new(0.7, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = config.Status or "Ready",
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = footer,
		})
		theme:register(status, { TextColor3 = "TextMuted" })
		self._status = status
		local footerBrand = create("TextLabel", {
			Name = "FooterBrand",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "Astrophysics",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = footer,
		})
		theme:register(footerBrand, { TextColor3 = "TextMuted" })

		-- ---------- Systems ----------
		self._notifier = Notifications.new({ screenGui = gui, theme = theme })
		maid:give(self._notifier)

		self._config = ConfigManager.new({
			folder = config.ConfigFolder or "Astrophysics",
			name = config.Title or "Window",
		})
		self.config = self._config

		self._keybinds = Keybinds.new({ maid = maid })
		self.keybinds = self._keybinds

		self._tooltip = Tooltip.new({ screenGui = gui, theme = theme, maid = maid })
		self.tooltip = self._tooltip

		self._search = Search.new({
			window = self,
			parent = window,
			navHolder = navHolder,
			searchButton = searchBtn,
			theme = theme,
			maid = maid,
		})
		self.search = self._search
		searchBtn.MouseButton1Click:Connect(function()
			self._search:toggle()
		end)

		-- Shared context handed to every component.
		self._ctx = {
			theme = theme,
			maid = maid,
			window = self,
			library = library,
			config = self._config,
			keybinds = self._keybinds,
			tooltip = self._tooltip,
			notify = function(o)
				self:Notify(o)
			end,
		}

		-- Dragger — the canonical motion. Bound to the top bar.
		Dragger({ window = root, handle = topbar, maid = maid })

		-- Global toggle keybind.
		local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift
		self._keybinds:setToggle(toggleKey, function()
			self:Toggle()
		end)
		self.toggleKey = toggleKey

		library._lastWindow = self

		-- Intro reveal.
		self._root.Visible = true
		self:Show()

		-- Autoload last profile once the UI exists so :Set() animations play.
		if config.AutoLoad then
			task.defer(function()
				self._config:autoload()
			end)
		end

		return self
	end

	-- ======================================================================
	-- Public library object
	-- ======================================================================
	local Library = {}
	Library.Version = "1.0.0"
	Library.Themes = Theme.list()

	function Library:CreateWindow(config)
		return buildWindow(self, config)
	end

	-- Standalone notifications (works even before/without a window).
	function Library:Notify(options)
		if self._lastWindow and not self._lastWindow._destroyed then
			self._lastWindow:Notify(options)
			return
		end
		if not self._globalNotifier then
			local gui = create("ScreenGui", {
				Name = "AstrophysicsToasts",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				DisplayOrder = 10000,
			})
			Utils.parentGui(gui)
			self._globalNotifier = Notifications.new({ screenGui = gui, theme = Theme.new("Nebula") })
		end
		self._globalNotifier:Notify(options)
	end

	function Library:SetGlobalTheme()
		-- Themes are per-window; placeholder for symmetry / future use.
	end

	return Library
end
