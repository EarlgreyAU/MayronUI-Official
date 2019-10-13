local _, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local _, _, _, _, obj = MayronUI:GetCoreComponents();
local oUF = namespace.oUF;
local UIParent, unpack = _G.UIParent, _G.unpack;

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");
local BaseUnitFrame = Engine:CreateClass("BaseUnitFrame", "Framework.System.FrameWrapper");

-- BaseUnitFrame -----------------------
Engine:DefineParams("string", "table");
---@param sv Observer @Unit frame db.profile settings
function BaseUnitFrame:__Construct(data, unitName, settings)
    data.unitName = unitName;
    data.settings = settings;
end

function BaseUnitFrame:SetEnabled(data)
    local frame = oUF:Spawn(data.unitName:lower(), "MUI_"..data.unitName.."Frame");
    frame:SetParent(UIParent);
    frame:SetPoint(unpack(data.settings.position));
    frame:SetSize(277, 70);
end

