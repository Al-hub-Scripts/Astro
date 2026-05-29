--[[
    Dragger.lua — the canonical cloud-like trailing drag (spec §7.1). This is
    the reference behaviour for the entire library's feel: the window does NOT
    snap to the cursor, it lag-follows on a long Quad/Out tween so it glides
    like it's floating on air. Every other motion in the lib is tuned to match
    this softness.

    Usage: Dragger({ window = Frame, handle = Frame, maid = Maid })
    `handle` is the top bar. Window control buttons live on top of the handle
    and sink their own clicks, so dragging only starts on empty bar area.
]]
return function(require)
	local Animations = require("Animations")
	local UserInputService = game:GetService("UserInputService")

	return function(opts)
		local window = opts.window
		local handle = opts.handle
		local maid = opts.maid

		local dragging = false
		local mouseStart -- Vector2 where the press began
		local frameStart -- UDim2 window position at press

		maid:give(handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				mouseStart = input.Position
				frameStart = window.Position
			end
		end))

		maid:give(UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - mouseStart
				-- Retargeting a fresh long tween every frame is exactly what
				-- produces the trailing "on air" lag — do not shorten this.
				Animations.tween(window, "Drag", {
					Position = UDim2.new(
						frameStart.X.Scale,
						frameStart.X.Offset + delta.X,
						frameStart.Y.Scale,
						frameStart.Y.Offset + delta.Y
					),
				})
			end
		end))

		maid:give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end))
	end
end
