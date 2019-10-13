-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, _, em, _, obj = MayronUI:GetCoreComponents();
local ASSETS = "interface\\addons\\MUI_UnitFrames\\Assets\\";

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");
local C_TargetUnitFrame = Engine:CreateClass("TargetUnitFrame", "PlayerUnitFrame");

-- C_PlayerUnitFrame -----------------------
function C_TargetUnitFrame:__Construct(_, unitID, settings)
    self:Super(unitID, settings);
end

function C_TargetUnitFrame:ApplyStyle(_, frame)
    self.Parent:ApplyStyle(frame);

	self.Health.colorDisconnected = true
	self.Health.colorTapping = true
end