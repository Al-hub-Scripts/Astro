--[[
    Utils.lua — instance helpers, connection/instance lifecycle (Maid),
    safe GUI parenting, and a tiny Signal.

    Every module is authored as a factory `function(require) ... end` so the
    same source works whether it's fetched+loadstring'd by Loader.lua or
    required as a ModuleScript by src/init.lua. `require` here is the
    string-name resolver supplied by whichever entry point loaded us.
]]
return function(require)
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local Animations = require("Animations")

	local Utils = {}

	-- create(class, props, children?) -> Instance
	-- Props are applied before children, and Parent is applied LAST so the
	-- engine doesn't reflow the layout once per property on a live tree.
	function Utils.create(className, props, children)
		local inst = Instance.new(className)
		local deferredParent = nil
		if props then
			deferredParent = props.Parent
			props.Parent = nil
			for key, value in pairs(props) do
				inst[key] = value
			end
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = inst
			end
		end
		if deferredParent then
			inst.Parent = deferredParent
		end
		return inst
	end

	-- Rounded corners. Pass a UDim or a number (offset px).
	function Utils.corner(parent, radius)
		return Utils.create("UICorner", {
			CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8),
			Parent = parent,
		})
	end

	-- 1px-ish outline. transparency defaults to opaque.
	function Utils.stroke(parent, color, thickness, transparency)
		return Utils.create("UIStroke", {
			Color = color or Color3.fromRGB(34, 34, 40),
			Thickness = thickness or 1,
			Transparency = transparency or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = parent,
		})
	end

	-- Uniform or per-side padding. Accepts a number (all sides) or a table
	-- { top, bottom, left, right } in offset pixels.
	function Utils.padding(parent, value)
		local t, b, l, r
		if type(value) == "table" then
			t, b, l, r = value.top or 0, value.bottom or 0, value.left or 0, value.right or 0
		else
			t, b, l, r = value, value, value, value
		end
		return Utils.create("UIPadding", {
			PaddingTop = UDim.new(0, t),
			PaddingBottom = UDim.new(0, b),
			PaddingLeft = UDim.new(0, l),
			PaddingRight = UDim.new(0, r),
			Parent = parent,
		})
	end

	function Utils.gradient(parent, colorSequence, rotation, transparency)
		return Utils.create("UIGradient", {
			Color = colorSequence,
			Rotation = rotation or 0,
			Transparency = transparency or NumberSequence.new(0),
			Parent = parent,
		})
	end

	-- Vertical/horizontal auto-layout convenience.
	function Utils.layout(parent, direction, padding, align)
		return Utils.create("UIListLayout", {
			FillDirection = direction or Enum.FillDirection.Vertical,
			Padding = UDim.new(0, padding or 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = (align and align.h) or Enum.HorizontalAlignment.Left,
			VerticalAlignment = (align and align.v) or Enum.VerticalAlignment.Top,
			Parent = parent,
		})
	end

	-- A UIScale used for soft press/open scaling without touching Size.
	function Utils.scaler(parent, value)
		return Utils.create("UIScale", { Scale = value or 1, Parent = parent })
	end

	function Utils.lerp(a, b, t)
		return a + (b - a) * t
	end

	function Utils.round(n, increment)
		if not increment or increment == 0 then
			return n
		end
		return math.floor(n / increment + 0.5) * increment
	end

	function Utils.clamp(n, lo, hi)
		return math.max(lo, math.min(hi, n))
	end

	-- ===================== Maid: lifecycle tracking =====================
	-- Tracks connections, instances, functions and objects so a Window (or
	-- component) can tear everything down with a single :clean() — this is the
	-- backbone of the "no leaks" guarantee.
	local Maid = {}
	Maid.__index = Maid

	function Maid.new()
		return setmetatable({ _items = {} }, Maid)
	end

	function Maid:give(item)
		if item ~= nil then
			table.insert(self._items, item)
		end
		return item
	end

	-- Give multiple at once.
	function Maid:giveAll(items)
		for _, item in ipairs(items) do
			self:give(item)
		end
	end

	function Maid:clean()
		local items = self._items
		self._items = {}
		for _, item in ipairs(items) do
			local kind = typeof(item)
			if kind == "RBXScriptConnection" then
				item:Disconnect()
			elseif kind == "Instance" then
				item:Destroy()
			elseif kind == "function" then
				pcall(item)
			elseif kind == "table" and (item.Destroy or item.clean) then
				pcall(function()
					(item.Destroy or item.clean)(item)
				end)
			end
		end
	end
	Maid.Destroy = Maid.clean
	Utils.Maid = Maid

	-- ===================== Lightweight Signal =====================
	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable({ _handlers = {} }, Signal)
	end

	function Signal:Connect(fn)
		local handlers = self._handlers
		handlers[fn] = true
		return {
			Disconnect = function()
				handlers[fn] = nil
			end,
		}
	end

	function Signal:Fire(...)
		for fn in pairs(self._handlers) do
			task.spawn(fn, ...)
		end
	end

	function Signal:Destroy()
		self._handlers = {}
	end
	Utils.Signal = Signal

	-- ===================== Safe GUI parenting =====================
	-- Try in the order the spec mandates: gethui -> syn.protect_gui+CoreGui ->
	-- CoreGui -> PlayerGui. Every step is guarded so a limited executor never
	-- hard-errors here.
	function Utils.parentGui(gui)
		local parented = false

		if typeof(gethui) == "function" then
			parented = pcall(function()
				gui.Parent = gethui()
			end)
		end

		if not parented and syn and typeof(syn.protect_gui) == "function" then
			parented = pcall(function()
				syn.protect_gui(gui)
				gui.Parent = CoreGui
			end)
		end

		if not parented then
			parented = pcall(function()
				gui.Parent = CoreGui
			end)
		end

		if not parented then
			pcall(function()
				local plr = Players.LocalPlayer
				gui.Parent = plr:WaitForChild("PlayerGui")
			end)
		end

		return gui
	end

	-- Best-effort screen size for off-screen notification slide-ins etc.
	function Utils.viewport()
		local cam = workspace.CurrentCamera
		return (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
	end

	-- ===================== Shared component scaffolding =====================
	-- The standard interactive row used by almost every component: an Elevated
	-- card with a stroke, a left-aligned name label, and room for a control on
	-- the right. Centralised here so all components share one look and pull
	-- every size from theme tokens (no per-file magic numbers).
	function Utils.element(theme, parent, opts)
		opts = opts or {}
		local root = Utils.create("Frame", {
			Name = opts.name or "Element",
			Size = UDim2.new(1, 0, 0, opts.height or theme:size("ElementHeight")),
			BackgroundColor3 = theme:get("Elevated"),
			BorderSizePixel = 0,
			Parent = parent,
		})
		theme:register(root, { BackgroundColor3 = "Elevated" })
		Utils.corner(root, theme:size("ElementCorner"))
		local stroke = Utils.stroke(root, theme:get("Stroke"), theme:size("StrokeThickness"))
		theme:register(stroke, { Color = "Stroke" })

		local label
		if opts.label ~= false then
			label = Utils.create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(opts.labelWidth or 0.55, -12, 1, 0),
				BackgroundTransparency = 1,
				Text = opts.name or "",
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = root,
			})
			theme:register(label, { TextColor3 = "TextPrimary" })
		end

		return { root = root, label = label, stroke = stroke }
	end

	-- The one hover feel, reused everywhere: a soft bg lift on enter, settle on
	-- leave. Connections are tracked by the supplied maid so nothing leaks.
	function Utils.hoverLift(theme, root, stroke, maid, opts)
		opts = opts or {}
		local restToken = opts.rest or "Elevated"
		local hoverToken = opts.hover or "ElevatedHover"
		maid:give(root.MouseEnter:Connect(function()
			if opts.guard and not opts.guard() then
				return
			end
			Animations.tween(root, "Hover", { BackgroundColor3 = theme:get(hoverToken) })
		end))
		maid:give(root.MouseLeave:Connect(function()
			Animations.tween(root, "Hover", { BackgroundColor3 = theme:get(restToken) })
		end))
	end

	return Utils
end
