-- luacheck: ignore self 143
local _, namespace = ...;

local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

namespace.auraAreaData = obj:PopTable();

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");
namespace.C_AurasModule = C_AurasModule;

---@class C_Aura : Object
local C_Aura = Engine:CreateClass("Aura", "Framework.System.FrameWrapper");
C_Aura.Static:AddFriendClass("AurasModule");

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");
C_AuraArea.Static:AddFriendClass("AurasModule");

---@type Stack
local Stack = obj:Import("Framework.System.Collections.Stack<T>");
local auraStack = Stack:Of(C_Aura)();

auraStack:OnNewItem(function()
    return C_Aura();
end);

auraStack:OnPushItem(function(aura)
    -- bar.ExpirationTime = -1;
    -- bar:SetShown(false);
    -- bar:SetParent(tk.Constants.DUMMY_FRAME);
end);

auraStack:OnPopItem(function(aura, auraId)
    -- data.barAdded = true; -- needed for controlling OnUpdate
    -- bar.AuraId = auraId;
    -- table.insert(data.activeBars, bar);
end);

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled       = true;
        width         = 250;
        height        = 27;
        showIcon      = false;
        unlocked      = false;
        frameStrata   = "MEDIUM";
        frameLevel    = 20;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
    };
    appearance = {
        texture       = "MUI_StatusBar";
        border        = "Skinner";
        borderSize    = 1;
        inset         = 1;
        colors = {
            finished    = {r = 0.8, g = 0.8, b = 0.8, a = 0.7};
            interrupted = {r = 1, g = 0, b = 0, a = 0.7};
            border      = {r = 0, g = 0, b = 0, a = 1};
            background  = {r = 0, g = 0, b = 0, a = 0.6};
            latency     = {r = 1, g = 1, b = 1, a = 0.6};
        };
    };
    Buffs = {
        position = {"TOP", "UIParent", "TOP", 0,  -200};
    };
    Debuffs = {
        position = {"TOP", "UIParent", "TOP", 0,  -200};
    };
});

-- C_Aura ----------------------

-- Engine:DefineParams("table", "table", "string");

-- TODO: Need to use the Stack object to create these!
function C_Aura:__Construct(data, settings, appearance)
    data.settings = settings;
    data.appearance = appearance;
    data.backdrop = obj:PopTable();

    local frame = _G.CreateFrame("Frame", nil, _G.UIParent);
    frame:SetAlpha(0);
    frame:SetBackdropBorder();

    frame.duration = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frame.duration:SetPoint("LEFT", 4, 0);
    frame.duration:SetWidth(150);
    frame.duration:SetWordWrap(false);
    frame.duration:SetJustifyH("LEFT");

    -- Needed for event functions
    namespace.castBarData[data.unitID] = data;
end

function C_Aura:UpdateAppearance()

end

-- C_AuraArea ----------------------

Engine:DefineParams("table", "table", "string");
function C_AuraArea:__Construct(data, settings, appearance, areaName)
    data.settings = settings;
    data.globalName = _G.string.format("MUI_%sArea", areaName);
    data.appearance = appearance;
    data.auras = obj:PopTable();

    -- Needed for event functions
    namespace.auraAreaData[data.unitID] = data;
end

do
    local function CheckAuras()

    end

    local function CreateAuraAreaFrame(settings, globalName)
        local area = _G.CreateFrame("Frame", globalName, _G.UIParent);
        area:SetSize(settings.width, settings.height);

        em:CreateUnitEventHandler("UNIT_AURA", CheckAuras, "Player");
        em:CreateEventHandler("GROUP_ROSTER_UPDATE", CheckAuras);
        em:CreateEventHandler("PLAYER_SPECIALIZATION_CHANGED", CheckAuras);

        return area;
    end

    Engine:DefineParams("boolean")
    function C_AuraArea:SetEnabled(data, enabled)
        local area = data.frame;

        if (not area and not enabled) then
            return;
        end

        if (enabled) then
            if (not area) then
                data.frame = CreateAuraAreaFrame(data.unitID, data.settings, data.globalName);
            end

            self:PositionCastBar();

            if (data.unitID == "mirror") then
                area:RegisterEvent("MIRROR_TIMER_PAUSE");
                area:RegisterEvent("MIRROR_TIMER_START");
                area:RegisterEvent("MIRROR_TIMER_STOP");
            else
                area:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", data.unitID);
                area:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", data.unitID);
                area:RegisterUnitEvent("UNIT_SPELLCAST_START", data.unitID);
                area:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", data.unitID);
                area:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", data.unitID);
                area:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", data.unitID);

                if (data.unitID == "target") then
                    area:RegisterEvent("PLAYER_TARGET_CHANGED");
                end
            end

            area.totalElapsed = 0;
            area.castarea = self;
            area.unitID = data.unitID;
            area:SetScript("OnUpdate", CastareaFrame_OnUpdate);
            area:SetScript("OnEvent", CastareaFrame_OnEvent);
        else
            area:UnregisterAllEvents();
            area:SetParent(tk.Constants.DUMMY_FRAME);
            area:SetAllPoints(tk.Constants.DUMMY_FRAME);
            area:SetScript("OnUpdate", nil);
            area:SetScript("OnEvent", nil);
        end

        area:SetShown(enabled);
        area.enabled = enabled;
    end
end

-- Events ---------------------
local Events = obj:PopTable();

---@param castBarData table
---@param pauseDuration number
function Events:MIRROR_TIMER_PAUSE(_, castBarData, pauseDuration)
    castBarData.paused = pauseDuration > 0;

    if (pauseDuration > 0) then
        castBarData.pauseDuration = pauseDuration;
    end
end

-- events:

-- function BuffButton_OnLoad(self)
-- 	self:RegisterForClicks("RightButtonUp");
-- end

-- function BuffButton_OnClick(self)
-- 	CancelUnitBuff(self.unit, self:GetID(), self.filter);
-- end


-- C_AurasModule -----------------------

function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

    -- TODO: Target should be here
    for _, barName in obj:IterateArgs("Buffs", "Debuffs") do
        local sv = db.profile.auras[barName]; ---@type Observer
        sv:SetParent(db.profile.auras.__templateAuraArea);
    end

    local options = {
        onExecuteAll = {
            first = {
                "Buffs.enabled";
                "Debuffs.enabled";
            };
        };
        groups = {
            {
                patterns = { "^%a+%.enabled$" };
                value = function(value, keysList)
                    local auraAreaName = keysList:PopFront();
                    local auraArea = data.auraAreas[auraAreaName];

                    if (value and not auraArea) then
                        auraArea = C_AuraArea(data.settings[auraAreaName], data.settings.appearance, auraAreaName);
                        data.auraAreas[auraAreaName] = auraArea;
                    end

                    if (auraArea) then
                        auraArea:SetEnabled(value);
                    end
                end;
            };
        };
    };

    self:RegisterUpdateFunctions(db.profile.auras, {
        appearance = {
            texture = function(value)
                local auraAreaData;

                for _, auraArea in _G.pairs(data.auraAreas) do
                    auraAreaData = data:GetFriendData(auraArea);
                    auraAreaData.frame.statusbar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", value));
                end
            end;
        }
    }, options);

    self:SetEnabled(true);
end