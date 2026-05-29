--[[ Tooltip — one shared floating label, soft fade-in after a short hover delay. ]]
return function(require)
	local Utils = require("Utils")
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	local Tooltip = {}
	Tooltip.__index = Tooltip

	local SHOW_DELAY = 0.45

	function Tooltip.new(ctx)
		local self = setmetatable({}, Tooltip)
		self.theme = ctx.theme

		local tip = Utils.create("CanvasGroup", {
			Name = "Tooltip",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = ctx.theme:get("Elevated"),
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 50,
			Parent = ctx.screenGui,
		})
		ctx.theme:register(tip, { BackgroundColor3 = "Elevated" })
		Utils.corner(tip, UDim.new(0, 6))
		local s = Utils.stroke(tip, ctx.theme:get("Stroke"), 1)
		ctx.theme:register(s, { Color = "Stroke" })
		Utils.padding(tip, { top = 5, bottom = 5, left = 9, right = 9 })

		local label = Utils.create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			Parent = tip,
		})
		ctx.theme:register(label, { TextColor3 = "TextPrimary" })

		self._tip = tip
		self._label = label
		ctx.maid:give(tip)
		return self
	end

	function Tooltip:_position()
		local loc = UserInputService:GetMouseLocation()
		local view = Utils.viewport()
		local size = self._tip.AbsoluteSize
		local x = math.min(loc.X + 14, view.X - size.X - 8)
		local y = math.min(loc.Y + 18, view.Y - size.Y - 8)
		self._tip.Position = UDim2.fromOffset(x, y)
	end

	function Tooltip:attach(target, text)
		local hovered = false
		target.MouseEnter:Connect(function()
			hovered = true
			task.delay(SHOW_DELAY, function()
				if not hovered then
					return
				end
				self._label.Text = text
				self._tip.Visible = true
				self:_position()
				Animations.tween(self._tip, "Hover", { GroupTransparency = 0 })
			end)
		end)
		target.MouseMoved:Connect(function()
			if hovered and self._tip.Visible then
				self:_position()
			end
		end)
		target.MouseLeave:Connect(function()
			hovered = false
			local tw = Animations.tween(self._tip, "Hover", { GroupTransparency = 1 })
			tw.Completed:Connect(function()
				if not hovered then
					self._tip.Visible = false
				end
			end)
		end)
	end

	function Tooltip:Destroy()
		if self._tip then
			self._tip:Destroy()
		end
	end

	return Tooltip
end
