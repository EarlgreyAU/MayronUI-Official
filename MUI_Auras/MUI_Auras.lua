-- luacheck: ignore self 143
local _, namespace = ...;

local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

namespace.auraAreaData = obj:PopTable();

local UnitAura, pairs, ipairs, table = _G.UnitAura, _G.pairs, _G.ipairs, _G.table;
local MAIN_ENCHANT = "MAIN_ENCHANT";
local OFF_ENCHANT = "OFF_ENCHANT";

local MAIN_ENCHANT_ID = 1016;
local OFF_ENCHANT_ID = 1017;

-- Objects -----------------------------

--TODO: Weapon enchant when first applied - Combat Log? Always have them created?
--TODO: Destroy buffs correctly
--TODO: Make configurable

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");
namespace.C_AurasModule = C_AurasModule;

---@class C_Aura : Object
local C_Aura = Engine:CreateClass("Aura", "Framework.System.FrameWrapper");

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");
C_AuraArea.Static:AddFriendClass("Aura");

---@type Stack
local Stack = obj:Import("Framework.System.Collections.Stack<T>");
local auraStack = Stack:Of(C_Aura)();

auraStack:OnNewItem(function(auraArea)
    return C_Aura(auraArea);
end);

auraStack:OnPushItem(function(aura)
    -- bar.ExpirationTime = -1;
    -- bar:SetShown(false);
    -- bar:SetParent(tk.Constants.DUMMY_FRAME);
end);

auraStack:OnPopItem(function(aura, auraArea)
    aura:SetArea(auraArea);
end);

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled       = true;
        unlocked      = false;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
        colSpacing = 4;
        rowSpacing = 16;
        perRow = 10;
        direction = "LEFT";
    };
    appearance = {
        border        = "Skinner";
        borderSize    = 1;
        inset         = 1;
    };
    Buffs = {
        position = {"TOP", "UIParent", "TOP", 0,  -200};
        auraType = "Buffs";
    };

    -- TODO
    -- Debuffs = {
    --     position = {"TOP", "UIParent", "TOP", 0,  -200};
    --     auraType = "Debuffs";
    -- };
});

-- C_Aura ----------------------
local function AuraFrame_OnEnter(self)
    _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        _G.GameTooltip:SetInventoryItem("player", self:GetID() - 1000);
    else
        _G.GameTooltip:SetUnitAura("player", self:GetID(), self.filter);
    end

    _G.GameTooltip:Show();
end

-- Engine:DefineParams("table", "table", "string");
function C_Aura:SetArea(data, auraArea)
    local areaData = data:GetFriendData(auraArea);
    data.frame:SetParent(areaData.frame);
    data.auraType = areaData.settings.auraType;
end

-- TODO: Need to use the Stack object to create these!
function C_Aura:__Construct(data, auraArea)
    data.backdrop = obj:PopTable();

    local frame = _G.CreateFrame("Frame");
    data.frame = frame;
    self:SetArea(auraArea);

    -- For testing only:
    frame:SetScript("OnEnter", AuraFrame_OnEnter);
    frame:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    -- SHOULD be in UpdateAppearance (called by auraArea)
    frame:SetSize(32, 32);
    data.background = tk:SetBackground(frame, 0, 0, 0);

    data.iconTexture = frame:CreateTexture(nil, "ARTWORK");
    data.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    data.iconTexture:SetPoint("TOPLEFT", 1, -1);
    data.iconTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    frame.countText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    frame.countText:SetPoint("BOTTOMRIGHT", 0, 2);

    frame.timeRemainingText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    frame.timeRemainingText:SetPoint("TOP", frame, "BOTTOM", 0, -2);
end

local function AuraFrame_OnUpdate(self, elapsed)
    if (self.timeSinceLastUpdate == nil) then
        self:SetScript("OnUpdate", nil);
        return;
    end

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    if (self.timeSinceLastUpdate > 1) then
        local _, _, count, _, _, expirationTime, _, _, _,
            _, _, _, _, _, timeMod = UnitAura("player", self:GetID(), "HELPFUL");

        if (not (count and expirationTime)) then
            return;
        end

        if (count < 1) then
            self.countText:SetText(tk.Strings.Empty);
        else
            self.countText:SetText(count);
        end

        local timeRemaining = expirationTime - _G.GetTime();

        if (timeRemaining > 0) then
            if (timeMod > 0) then
                timeRemaining = timeRemaining / timeMod;
            end

            self.timeRemmaining = timeRemaining;
            self.timeRemainingText:SetFormattedText(_G.SecondsToTimeAbbrev(timeRemaining));
        else
            self.timeRemmaining = nil;
            self.timeRemainingText:SetText(tk.Strings.Empty);
        end

        self.timeSinceLastUpdate = 0;
    end
end

local function AuraEnchantFrame_OnUpdate(self, elapsed)
    if (self.timeSinceLastUpdate == nil) then
        self:SetScript("OnUpdate", nil);
        return;
    end

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    if (self.timeSinceLastUpdate > 1) then
        local expirationTime, count;

        if (self:GetID() == MAIN_ENCHANT_ID) then
            expirationTime, count = select(2, _G.GetWeaponEnchantInfo());
        else
            expirationTime, count = select(6, _G.GetWeaponEnchantInfo());
        end

        if (not (count and expirationTime)) then
            return;
        end

        if (count < 1) then
            self.countText:SetText(tk.Strings.Empty);
        else
            self.countText:SetText(count);
        end

        if (expirationTime) then
            expirationTime = expirationTime / 1000;
            self.timeRemmaining = expirationTime;
            self.timeRemainingText:SetFormattedText(_G.SecondsToTimeAbbrev(expirationTime));
        else
            self.timeRemmaining = nil;
            self.timeRemainingText:SetText(tk.Strings.Empty);
        end

        self.timeSinceLastUpdate = 0;
    end
end

function C_Aura:StartUpdate(data, index, iconTexture, isEnchant)
    -- needed for tooltip
    data.frame:SetID(index);

    if (isEnchant) then
        data.frame.filter = nil; -- weapon enchant
    else
        if (data.auraType == "Buffs") then
            data.frame.filter = "HELPFUL";
        else
            data.frame.filter = "HARMFUL";
        end
    end

    data.iconTexture:SetTexture(iconTexture);

    if (isEnchant) then
        data.background:SetVertexColor(0.53, 0.23, 0.78);
    else
        data.background:SetVertexColor(0, 0, 0);
    end

    if (not data.timeSinceLastUpdate) then
        data.frame.timeSinceLastUpdate = 0;

        if (isEnchant) then
            data.frame:SetScript("OnUpdate", AuraEnchantFrame_OnUpdate);
        else
            data.frame:SetScript("OnUpdate", AuraFrame_OnUpdate);
        end
    end
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
end

do
    local function SetUpAura(auraArea, auras, id, iconTexture)
        local aura = auras[id]; ---@type C_Aura

        if (not aura) then
            auras[id] = auraStack:Pop(auraArea);
            aura = auras[id];
        end

        local isEnchant = id == MAIN_ENCHANT_ID or id == OFF_ENCHANT_ID;
        aura:StartUpdate(id, iconTexture, isEnchant);
    end

    ---@param auraArea C_AuraArea
    local function CheckAuras(_, eventName, auraArea, auraType, auras, ...)
        if (auraType:lower() == "buffs") then
            local hasMainHandEnchant, _, _, _, hasOffHandEnchant = _G.GetWeaponEnchantInfo();

            if (hasMainHandEnchant) then
                local iconTexture = _G.GetInventoryItemTexture("player", MAIN_ENCHANT_ID - 1000); -- main hand (offhand 17)
                SetUpAura(auraArea, auras, MAIN_ENCHANT_ID, iconTexture);

            elseif (auras[MAIN_ENCHANT]) then
                auraArea:RemoveAuraByName(MAIN_ENCHANT);
            end

            if (hasOffHandEnchant) then
                local iconTexture = _G.GetInventoryItemTexture("player", OFF_ENCHANT_ID - 1000); -- main hand (offhand 17)
                SetUpAura(auraArea, auras, OFF_ENCHANT_ID, iconTexture);

            elseif (auras[OFF_ENCHANT]) then
                auraArea:RemoveAuraByName(OFF_ENCHANT);
            end

            for index = 1, _G.BUFF_MAX_DISPLAY do
                local name, iconTexture = UnitAura("player", index, "HELPFUL");

                if (name) then
                    SetUpAura(auraArea, auras, index, iconTexture);
                elseif (auras[name]) then
                    auraArea:RemoveAuraByName(name);
                end
            end
        else
            -- TODO!
            for index = 1, _G.DEBUFF_MAX_DISPLAY do
                local name, iconTexture = UnitAura("player", index, "HARMFUL");

                if (name) then
                    SetUpAura(auraArea, auras, index, iconTexture);
                elseif (auras[name]) then
                    auraArea:RemoveAuraByName(name);
                end
            end
        end

        auraArea:RefreshAnchors();
    end

    Engine:DefineReturns("Frame")
    function C_AuraArea:CreateAuraAreaFrame(data)
        local area = _G.CreateFrame("Frame", data.globalName, _G.UIParent);

        -- TODO: For testing ONLY! (comment out when done)
        area:SetSize(500, 200);
        area:SetPoint("CENTER");
        tk:MakeMovable(area);
        tk:SetBackground(area, 1, 1, 1, 0.5);

        -- Can I shorten this?
        em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", CheckAuras, "Player")
            :SetCallbackArgs(self, data.settings.auraType, data.auras)
            :AppendEvent("GROUP_ROSTER_UPDATE")
            :AppendEvent("PLAYER_ENTERING_WORLD");

        return area;
    end
end

Engine:DefineParams("boolean")
function C_AuraArea:SetEnabled(data, enabled)
    local area = data.frame;

    if (not area and not enabled) then
        return;
    end

    if (enabled) then
        if (not area) then
            data.frame = self:CreateAuraAreaFrame();
            area = data.frame;
        end
    else
        em:DestroyEventHandlerByKey(data.globalName.."Handler");
        area:SetParent(tk.Constants.DUMMY_FRAME);
        area:SetAllPoints(tk.Constants.DUMMY_FRAME);
    end

    area:SetShown(enabled);
    data.enabled = enabled;
end

function C_AuraArea:RemoveAuraByName(data, auraName)
    local aura = data.auras[auraName];
    data.auras[auraName] = nil;

    aura:GetFrame():SetScript("OnUpdate", nil);
    self:RefreshAnchors();

    auraStack:Push(aura);
end

local function SortAurasByTimeRemaining(a, b)
    if (not a.timeRemaining and not b.timeRemaining) then
        return 0;
    end

    if (not a.timeRemaining) then
        return -1;
    end

    if (not b.timeRemaining) then
        return 1;
    end

    return a.timeRemaining < b.timeRemaining;
end

function C_AuraArea:RefreshAnchors(data)
    local auras = obj:PopTable();
    local frame;

    for auraName, aura in pairs(data.auras) do
        if (auraName ~= MAIN_ENCHANT and auraName ~= OFF_ENCHANT) then
            -- TODO: what about expired?
            frame = aura:GetFrame();
            frame:ClearAllPoints();
            table.insert(auras, frame);
        end
    end

    -- sort by time remaining:
    table.sort(auras, SortAurasByTimeRemaining)

    if (data.auras[MAIN_ENCHANT]) then
        frame = data.auras[MAIN_ENCHANT]:GetFrame();
        frame:ClearAllPoints();
        table.insert(auras, 1, frame);
    end

    if (data.auras[OFF_ENCHANT]) then
        frame = data.auras[OFF_ENCHANT]:GetFrame();
        frame:ClearAllPoints();
        table.insert(auras, 2, frame);
    end

    local totalPositioned = 0;

    for id, aura in ipairs(auras) do
        -- TODO: what about expired?
        if (id == 1) then
            if (data.settings.direction == "LEFT") then
                aura:SetPoint("TOPRIGHT");
            elseif (data.settings.direction == "RIGHT") then
                aura:SetPoint("TOPLEFT");
            end

        elseif (totalPositioned % data.settings.perRow == 0) then
            local anchor = auras[(totalPositioned - data.settings.perRow) + 1];
            aura:SetPoint("TOP", anchor, "BOTTOM", 0, -data.settings.rowSpacing);
        else
            if (data.settings.direction == "LEFT") then
                aura:SetPoint("RIGHT", auras[id - 1], "LEFT", -data.settings.colSpacing, 0);
            elseif (data.settings.direction == "RIGHT") then
                aura:SetPoint("LEFT", auras[id - 1], "RIGHT", data.settings.colSpacing, 0);
            end

        end

        totalPositioned = totalPositioned + 1;
    end

    obj:PushTable(auras);
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
    for _, barName in obj:IterateArgs("Buffs") do -- TODO: Add Debuffs
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