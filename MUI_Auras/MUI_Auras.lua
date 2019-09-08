-- luacheck: ignore self 143
local _, namespace = ...;

local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

local GetTime, SecondsToTimeAbbrev, GetWeaponEnchantInfo, select, UnitAura, pairs, ipairs,
    table, tostring, CreateFrame, GameTooltip, unpack, math, GetInventoryItemTexture, string,
    BUFF_MAX_DISPLAY, DEBUFF_MAX_DISPLAY, UIParent =
    _G.GetTime, _G.SecondsToTimeAbbrev, _G.GetWeaponEnchantInfo, _G.select, _G.UnitAura,
    _G.pairs, _G.ipairs, _G.table, _G.tostring, _G.CreateFrame, _G.GameTooltip, _G.unpack,
    _G.math, _G.GetInventoryItemTexture, _G.string, _G.BUFF_MAX_DISPLAY, _G.DEBUFF_MAX_DISPLAY, _G.UIParent;

local MAIN_ENCHANT_ID = 1016;
local OFF_ENCHANT_ID = 1017;
local framesToUpdate = {};

-- Objects -----------------------------

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

auraStack:OnNewItem(function(auraArea, id)
    return C_Aura(auraArea, id);
end);

auraStack:OnPushItem(function(aura)
    local areaFrame = aura:GetAreaFrame();
    local areaTable = framesToUpdate[tostring(areaFrame)];
    local index = tk.Tables:IndexOf(areaTable, aura:GetFrame());

    table.remove(areaTable, index);
end);

auraStack:OnPopItem(function(aura, auraArea, id)
    aura:SetArea(auraArea);
    aura:SetID(id);
end);

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled       = true;
        unlocked      = false;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
        colSpacing = 4;
        rowSpacing = 16;
        perRow = 15;
        direction = "LEFT";
        showEnchants = false;
        auraSize = 32;
    };
    appearance = {
        border        = "Skinner";
        borderSize    = 1;
        inset         = 1;
    };
    Buffs = {
        position = {"TOPRIGHT", "Minimap", "TOPLEFT", -4, 0};
        auraType = "Buffs";
        showEnchants = true;
    };

    Debuffs = {
        position = {"TOPRIGHT", "MUI_BuffsArea", "BOTTOMRIGHT", 0, -10};
        auraType = "Debuffs";
    };
});

-- C_Aura ----------------------
local function AuraFrame_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        GameTooltip:SetInventoryItem("player", self:GetID() - 1000);
    else
        GameTooltip:SetUnitAura("player", self:GetID(), self.filter);
    end

    GameTooltip:Show();
end

-- Engine:DefineParams("table", "table", "string");
function C_Aura:SetArea(data, auraArea)
    local areaData = data:GetFriendData(auraArea);
    data.frame:SetParent(areaData.frame);
    data.areaFrame = areaData.frame;
    data.auraType = areaData.settings.auraType;

    if (data.auraType == "Buffs") then
        data.frame:SetAttribute("type2", "cancelaura");
        data.frame:SetAttribute("cancelaura", "player", data.frame:GetID());
    else
        data.frame:SetAttribute("type2", nil);
        data.frame:SetAttribute("cancelaura", nil);
    end

    table.insert(framesToUpdate[tostring(areaData.frame)], data.frame);
end

function C_Aura:GetAreaFrame(data)
    return data.areaFrame;
end

-- TODO: Need to use the Stack object to create these!
function C_Aura:__Construct(data, auraArea, id)
    data.backdrop = obj:PopTable();

    local btn = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate");
    btn:SetID(id);
    btn:RegisterForClicks("RightButtonUp");

    data.frame = btn; -- needed for GetFrame()
    self:SetArea(auraArea);

    btn:SetScript("OnEnter", AuraFrame_OnEnter);
    btn:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    -- SHOULD be in UpdateAppearance (called by auraArea)
    btn:SetSize(32, 32);

    if (id == MAIN_ENCHANT_ID or id == OFF_ENCHANT_ID) then
        data.background = tk:SetBackground(btn, 0.53, 0.23, 0.78);
    else
        data.background = tk:SetBackground(btn, 0, 0, 0);
    end

    btn.iconTexture = btn:CreateTexture(nil, "ARTWORK");
    btn.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    btn.iconTexture:SetPoint("TOPLEFT", 1, -1);
    btn.iconTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    btn.countText:SetPoint("BOTTOMRIGHT", 0, 2);

    btn.timeRemainingText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    btn.timeRemainingText:SetPoint("TOP", btn, "BOTTOM", 0, -2);
end

local function AuraFrame_OnUpdate(self)
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

    local timeRemaining = expirationTime - GetTime();

    if (timeRemaining > 0) then
        if (timeMod > 0) then
            timeRemaining = timeRemaining / timeMod;
        end

        self.timeRemaining = timeRemaining;
        self.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(timeRemaining));
    else
        self.timeRemaining = nil;
        self.timeRemainingText:SetText(tk.Strings.Empty);
    end
end

local function AuraEnchantFrame_OnUpdate(self, globalName)
    local id = self:GetID();
    local hasEnchant, expirationTime, count;

    if (id == MAIN_ENCHANT_ID) then
        hasEnchant, expirationTime, count = GetWeaponEnchantInfo();
    else
        hasEnchant, expirationTime, count = select(5, GetWeaponEnchantInfo());
    end

    self.filter = nil; -- weapon enchant

    if (not hasEnchant) then
        self:SetAllPoints(tk.Constants.DUMMY_FRAME);
        self:Hide();
        self.isEnchantActive = nil;
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
        return;
    end

    local iconTexture = GetInventoryItemTexture("player", MAIN_ENCHANT_ID - 1000);
    self.iconTexture:SetTexture(iconTexture);

    if (count < 1) then
        self.countText:SetText(tk.Strings.Empty);
    else
        self.countText:SetText(count);
    end

    if (expirationTime) then
        expirationTime = expirationTime / 1000;
        self.timeRemaining = expirationTime;
        self.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(expirationTime));
    else
        self.timeRemaining = nil;
        self.timeRemainingText:SetText(tk.Strings.Empty);
    end

    -- ensure that PLAYER_ENTERING_WORLD works for enchants
    if (not self.isEnchantActive) then
        self.isEnchantActive = true;
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
    end
end

function C_Aura:Enable(data, iconTexture)
    -- needed for tooltip
    if (data.auraType == "Buffs") then
        data.frame.filter = "HELPFUL";
    else
        data.frame.filter = "HARMFUL";
    end

    data.frame.iconTexture:SetTexture(iconTexture);
    data.background:SetVertexColor(0, 0, 0);
end

function C_Aura:UpdateAppearance()

end

function C_Aura:Disable(data)
    data.frame:SetAllPoints(tk.Constants.DUMMY_FRAME);
    data.frame:Hide();
    auraStack:Push(self);
end

-- C_AuraArea ----------------------

Engine:DefineParams("table", "string");
function C_AuraArea:__Construct(data, settings, areaName)
    data.settings = settings[areaName];
    data.globalName = string.format("MUI_%sArea", areaName);
    data.appearance = settings.appearance;
    data.auras = obj:PopTable();
    data.auras.Buffs = obj:PopTable();
    data.auras.Debuffs = obj:PopTable();
end

do
    ---@param auraArea C_AuraArea
    ---@param mainHandAura C_Aura
    ---@param offHandAura C_Aura
    local function CheckAuras(_, _, auraArea, auras, auraType)
        local activeAuras = obj:PopTable();
        local filter, global;

        if (auraType == "Buffs") then
            filter, global = "HELPFUL", BUFF_MAX_DISPLAY;
        else
            filter, global = "HARMFUL", DEBUFF_MAX_DISPLAY;
        end

        for index = 1, global do
            local aura = auras[auraType][index]; ---@type C_Aura
            local name, iconTexture = UnitAura("player", index, filter);

            if (name) then
                if (not aura) then
                    auras[auraType][index] = auraStack:Pop(auraArea, index);
                    aura = auras[auraType][index];
                end

                aura:Enable(iconTexture, false);
                table.insert(activeAuras, aura);

            elseif (aura) then
                aura:Disable();
            end
        end

        obj:PushTable(auras[auraType]);
        auras[auraType] = activeAuras;

        auraArea:RefreshAnchors(auras[auraType]);
    end

    function C_AuraArea:CreateAuraAreaFrame(data)
        data.frame = CreateFrame("Frame", data.globalName, UIParent);
        framesToUpdate[tostring(data.frame)] = obj:PopTable();

        local s = data.settings;
        data.frame:SetSize(
            ((s.auraSize + s.colSpacing) * s.perRow) - s.colSpacing,
            ((s.auraSize + s.rowSpacing) * math.ceil(BUFF_MAX_DISPLAY / s.perRow)) - s.rowSpacing);

        data.frame:SetPoint(unpack(s.position));

        if (data.settings.showEnchants) then
            data.mainHandAura = auraStack:Pop(self, MAIN_ENCHANT_ID);
            data.offHandAura = auraStack:Pop(self, OFF_ENCHANT_ID);
        end

        -- Can I shorten this?
        em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", CheckAuras, "Player")
            :SetCallbackArgs(self, data.auras, data.settings.auraType)
            :AppendEvent("GROUP_ROSTER_UPDATE")
            :AppendEvent("PLAYER_ENTERING_WORLD");
    end
end

do
    -- should only handle updating time remaining and counts
    local function AuraArea_OnUpdate(self, elapsed)
        self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

        if (self.timeSinceLastUpdate < 1 and not self.forceUpdate) then
            return;
        end

        self.timeSinceLastUpdate = 0;
        self.forceUpdate = nil;

        for _, auraFrame in ipairs(framesToUpdate[tostring(self)]) do
            local id = auraFrame:GetID();

            if (id == MAIN_ENCHANT_ID or id == OFF_ENCHANT_ID) then
                AuraEnchantFrame_OnUpdate(auraFrame, self:GetName());
            else
                AuraFrame_OnUpdate(auraFrame);
            end
        end
    end

    Engine:DefineParams("boolean")
    function C_AuraArea:SetEnabled(data, enabled)
        if (not data.frame and not enabled) then
            return;
        end

        if (enabled) then
            if (not data.frame) then
                self:CreateAuraAreaFrame();
            end

            data.frame.timeSinceLastUpdate = 0;
            data.frame:SetScript("OnUpdate", AuraArea_OnUpdate);

            -- Hide Blizzard frames
            tk:KillElement(_G.BuffFrame);
            tk:KillElement(_G.TemporaryEnchantFrame);
        else
            data.frame:SetScript("OnUpdate", nil);
            em:DestroyEventHandlerByKey(data.globalName.."Handler");
            data.frame:SetParent(tk.Constants.DUMMY_FRAME);
            data.frame:SetAllPoints(tk.Constants.DUMMY_FRAME);
        end

        data.frame:SetShown(enabled);
        data.enabled = enabled;
    end
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

    return a.timeRemaining > b.timeRemaining;
end

Engine:SetAttribute("Framework.System.Attributes.InCombatAttribute");
function C_AuraArea:RefreshAnchors(data, activeAuras)
    data.frame.forceUpdate = true;

    local frames = obj:PopTable();

    for _, aura in pairs(activeAuras) do
        local frame = aura:GetFrame();

        obj:Assert(frame, "Frame is nil");

        frame:ClearAllPoints();
        table.insert(frames, frame);
    end

    -- sort by time remaining:
    table.sort(frames, SortAurasByTimeRemaining)

    if (data.mainHandAura and data.offHandAura) then
        local mainHandFrame = data.mainHandAura:GetFrame();
        local offHandFrame = data.offHandAura:GetFrame();

        if (mainHandFrame.isEnchantActive) then
            mainHandFrame:ClearAllPoints();
            table.insert(frames, 1, mainHandFrame);
        end

        if (offHandFrame.isEnchantActive) then
            offHandFrame:ClearAllPoints();
            table.insert(frames, 2, offHandFrame);
        end
    end

    local totalPositioned = 0;

    for id, auraFrame in ipairs(frames) do
        if (id == 1) then
            if (data.settings.direction == "LEFT") then
                auraFrame:SetPoint("TOPRIGHT");
            elseif (data.settings.direction == "RIGHT") then
                auraFrame:SetPoint("TOPLEFT");
            end

        elseif (totalPositioned % data.settings.perRow == 0) then
            local anchor = frames[(totalPositioned - data.settings.perRow) + 1];
            auraFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -data.settings.rowSpacing);
        else
            if (data.settings.direction == "LEFT") then
                auraFrame:SetPoint("RIGHT", frames[id - 1], "LEFT", -data.settings.colSpacing, 0);
            elseif (data.settings.direction == "RIGHT") then
                auraFrame:SetPoint("LEFT", frames[id - 1], "RIGHT", data.settings.colSpacing, 0);
            end
        end

        auraFrame:Show();
        totalPositioned = totalPositioned + 1;
    end
end

-- C_AurasModule -----------------------
function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

    -- TODO: Target should be here
    for _, barName in obj:IterateArgs("Buffs", "Debuffs") do -- TODO: Add Debuffs
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
                        auraArea = C_AuraArea(data.settings, auraAreaName);
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

                for _, auraArea in pairs(data.auraAreas) do
                    auraAreaData = data:GetFriendData(auraArea);
                    auraAreaData.frame.statusbar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", value));
                end
            end;
        }
    }, options);

    self:SetEnabled(true);
end