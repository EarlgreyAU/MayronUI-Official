local _, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, db, em, _, obj = MayronUI:GetCoreComponents();

local GetTime, select, SecondsToTimeAbbrev, GetWeaponEnchantInfo, UnitAura, ipairs,
    CreateFrame, GameTooltip, unpack, math, GetInventoryItemTexture, string, BUFF_MAX_DISPLAY,
    DEBUFF_MAX_DISPLAY, UIParent, InCombatLockdown, table, CancelUnitBuff = _G.GetTime, _G.select,
    _G.SecondsToTimeAbbrev, _G.GetWeaponEnchantInfo, _G.UnitAura, _G.ipairs, _G.CreateFrame,
    _G.GameTooltip, _G.unpack, _G.math,_G.GetInventoryItemTexture, _G.string, _G.BUFF_MAX_DISPLAY,
    _G.DEBUFF_MAX_DISPLAY, _G.UIParent, _G.InCombatLockdown, _G.table, _G.CancelUnitBuff;

-- Main-Hand, Off-Hand, Ranged
local enchantAuraIds = { 16, 17, 18 };
local ARGS_PER_ITEM = 4;

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class AurasModule : BaseModule
local C_AurasModule = MayronUI:RegisterModule("AurasModule", "Auras (Buffs & Debuffs)");
namespace.C_AurasModule = C_AurasModule;

---@class C_AuraArea : Object
local C_AuraArea = Engine:CreateClass("AuraArea", "Framework.System.FrameWrapper");
C_AuraArea.Static:AddFriendClass(C_AurasModule);

---@type Stack
local Stack = obj:Import("Framework.System.Collections.Stack<T>");
local auraStack = Stack:Of("Button")();

-- Load Database Defaults --------------

db:AddToDefaults("profile.auras", {
    __templateAuraArea = {
        enabled = true;
        position = {"CENTER", "UIParent", "CENTER", 0,  0};
        textSize = {
            timeRemaining   = 10;
            count           = 14;

            statusBars = {
                auraName        = 10;
                timeRemaining   = 10;
                count           = 12;
            }
        };
        textPosition = {
            timeRemaining   = {0, -2};
            count           = {0, 2};

            statusBars = {
                timeRemaining   = {-4, 0};
                count           = {0, 2};
                auraName        = {32, 0};
            }
        };
        border = {
            type = "Skinner";
            size = 1;
            show = true;
        };
        colors = {
            enchant               = {0.53, 0.23, 0.78};
            statusBarBackground   = {0, 0, 0, 0.5};
            timeRemaining         = {tk:GetThemeColor()};
            count                 = {1, 1, 1};
            auraName              = {tk:GetThemeColor()};
        };
        icons = {
            auraSize        = 32;
            borderSize      = 1;
            colSpacing      = 4;
            rowSpacing      = 16;
            perRow          = 16;
            growDirection   = "LEFT";
        };
        statusBars = {
            enabled           = true; -- change to false once done
            barAlpha          = 1;
            barTexture        = "MUI_StatusBar";
            width             = 260;
            height            = 24;
            spacing           = 4;
            growDirection     = "DOWN";
            borderSize        = 4;
        };
    };
    Buffs = {
        position = {"TOPRIGHT", "Minimap", "TOPLEFT", -4, 0};
        showPulseEffect = true;
        colors = {
            aura = {0, 0, 0};
            statusBarAura = { 0.1, 0.1, 0.1 };
        }
    };

    Debuffs = {
        position = {"TOPRIGHT", "MUI_BuffsArea", "BOTTOMRIGHT", 0, -10};
        colors = {
            aura    = {0.76, 0.2, 0.2};
            statusBarAura = {0.76, 0.2, 0.2};
            magic   = {0.2, 0.6, 1};
            disease = {0.6, 0.4, 0};
            poison  = {0.0, 0.6, 0};
            curse   = {0.6, 0.0, 1};
        }
    };
});

-- Local Functions -------------

local function AuraButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0);

    if (not self.filter) then
        GameTooltip:SetInventoryItem("player", self:GetID());
    else
        GameTooltip:SetUnitAura("player", self:GetID(), self.filter);
    end

    GameTooltip:Show();
end

local function UpdateTextAppearance(settings, name, btn, point, relativePoint, relativeFrame) --luacheck:ignore
    local fontString = btn[name.."Text"];
    fontString:SetTextColor(unpack(settings.colors[name]));

    relativeFrame = relativeFrame or btn;

    if (btn.statusBar) then
        fontString:SetPoint(point, relativeFrame, relativePoint, unpack(settings.textPosition.statusBars[name]));
        tk:SetFontSize(fontString, settings.textSize.statusBars[name]);
    else
        fontString:SetPoint(point, relativeFrame, relativePoint, unpack(settings.textPosition[name]));
        tk:SetFontSize(fontString, settings.textSize[name]);
    end
end

local function UpdateAuraButtonAppearance(settings, btn)
    local statusBars = settings.statusBars;
    local _, _, _, debuffType = UnitAura("player", btn:GetID(), btn.filter);
    local auraColor =  settings.colors.auras;

    if (statusBars.enabled) then
        auraColor = settings.colors.statusBarAura;
    end

    if (btn.filter == "HARMFUL") then
        if (debuffType) then
            auraColor = settings.colors[debuffType:lower()];
        end
    elseif (not btn.filter) then
        auraColor = settings.colors.enchant;
    end

    UpdateTextAppearance(settings, "count", btn, "BOTTOMRIGHT", "BOTTOMRIGHT", btn.iconTexture);


    if (statusBars.enabled) then
        btn:SetSize(statusBars.width, statusBars.height);
        btn.iconTexture:SetWidth(statusBars.height);
        btn.iconTexture:SetPoint("TOPLEFT", statusBars.borderSize, -statusBars.borderSize);
        btn.iconTexture:SetPoint("BOTTOMLEFT", statusBars.borderSize, statusBars.borderSize);

        btn.statusBar:SetPoint("TOPLEFT", statusBars.borderSize, -statusBars.borderSize);
        btn.statusBar:SetPoint("BOTTOMRIGHT", -statusBars.borderSize, statusBars.borderSize);
        btn.statusBar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", statusBars.barTexture));

        btn.background:SetVertexColor(settings.colors.statusBarBackground);
        btn.background:SetAlpha(settings.colors.statusBarBackground[4]);

        if (obj:IsTable(auraColor)) then
            btn.statusBar:SetStatusBarColor(unpack(auraColor));
        end

        UpdateTextAppearance(settings, "auraName", btn, "LEFT", "LEFT");
        btn.auraNameText:SetJustifyH("LEFT");

        UpdateTextAppearance(settings, "timeRemaining", btn, "RIGHT", "RIGHT");
        btn.timeRemainingText:SetJustifyH("RIGHT");
    else
        btn:SetSize(settings.icons.auraSize, settings.icons.auraSize);
        btn.iconTexture:SetPoint("TOPLEFT", settings.icons.borderSize, -settings.icons.borderSize);
        btn.iconTexture:SetPoint("BOTTOMRIGHT", -settings.icons.borderSize,settings.icons.borderSize);

        if (obj:IsTable(auraColor)) then
            btn.background:SetVertexColor(unpack(auraColor));
        end

        UpdateTextAppearance(settings, "timeRemaining", btn, "TOP", "BOTTOM");
    end
end

local function UpdateIconTexture(btn, iconTexture)
    if (iconTexture) then
        btn.iconTexture:SetTexture(iconTexture);
        btn:Show();
        btn.forceUpdate = true;
    else
        btn:Hide();
    end
end

local GetEnchantName;

do
    local scanner;

    local function GetEnchantNameBySlotID(slotID)
		for i = 1, 60 do
			scanner.lines[i]:SetText("");
        end

		scanner:SetInventoryItem("Player", slotID);

		for i = 1, 60 do
			local text = scanner.lines[i]:GetText();

            if (text) then
                local match = select(3, string.find(text, "^(.+) %(%d+ [^%)]+%)$"));

                if match then
					match = string.gsub(match, " %(%d+ [^%)]+%)", "");
					return match;
				end
            end
        end

		return nil;
    end

    GetEnchantName = function(slotID)
        if (not scanner) then
            scanner = CreateFrame("GameTooltip");
            scanner:SetOwner(UIParent, "ANCHOR_NONE");
            scanner.lines = obj:PopTable();

            for _ = 1, 30 do
                local left = scanner:CreateFontString(nil, "ARTWORK", "GameFontNormal");
                local right = scanner:CreateFontString(nil, "ARTWORK", "GameFontNormal");

                scanner:AddFontStrings(left, right)
                table.insert(scanner.lines, left);
                table.insert(scanner.lines, right);
            end
        end

        local enchantName = GetEnchantNameBySlotID(slotID);

        if (enchantName) then
            return enchantName;
        end

        -- If we cannot find the enchant name from tooltip then use the items's name:
        local itemlink = _G.GetInventoryItemLink("player", slotID);

        if (itemlink) then
            local itemName = _G.GetItemInfo(itemlink);

            if (itemName) then
                return itemName;
            end
        end

        -- If item cannot be found (should never happen) then use fallback name:
        return "Weapon "..slotID;
    end
end

---@param auras table
---@param totalAuras number
---@param filter string
local function AuraArea_OnEvent(_, _, auraArea, data)
    if (data.enchantButtons) then
        local totalArgs = select("#", GetWeaponEnchantInfo());
        local totalEnchantItems = totalArgs / ARGS_PER_ITEM;

        -- check weapon enchant auras:
        for index = 1, totalEnchantItems do
            local hasEnchant = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());
            local btn = data.enchantButtons[index];

            if (data.settings.statusBars.enabled) then
                local name = GetEnchantName(enchantAuraIds[index]);
                btn.auraNameText:SetText(name);
            end

            UpdateIconTexture(btn, hasEnchant and GetInventoryItemTexture("player", btn:GetID()));
        end
    end

    for auraID = 1, data.totalAuras do
        local name, iconTexture, _, debuffType = UnitAura("player", auraID, data.filter);
        local btn = data.auraButtons[auraID];

        if (name and iconTexture) then
            btn = btn or auraStack:Pop(data.frame, auraID, data.settings, data.filter);
            data.auraButtons[auraID] = btn;
        end

        if (btn) then
            UpdateIconTexture(btn, name and iconTexture);

            if (data.settings.statusBars.enabled) then
                btn.auraNameText:SetText(name);
            end

            if (data.filter == "HARMFUL") then
                local color = data.settings.colors.aura;

                if (debuffType) then
                    color = data.settings.colors[debuffType:lower()];
                end

                if (obj:IsTable(color)) then
                    btn.background:SetVertexColor(unpack(color));
                end
            end
        end
    end

    auraArea:RefreshAnchors();
end

local function AuraButton_UpdateAlpha(self, elapsed)
    self.pulseTime = (self.pulseTime or 0) - elapsed;

    if (self.pulseTime < 0) then
        local overtime = -self.pulseTime;

        if (self.isPulsing == 0) then
            self.isPulsing = 1;
            self.pulseTime = _G.BUFF_FLASH_TIME_ON;
        else
            self.isPulsing = 0;
            self.pulseTime = _G.BUFF_FLASH_TIME_OFF;
        end

        if (overtime < self.pulseTime) then
            self.pulseTime = self.pulseTime - overtime;
        end
    end

    local expirationTime = select(6, UnitAura("player", self:GetID(), self.filter));

    if (not expirationTime or expirationTime <= 0) then
        self:SetAlpha(1);
        return;
    end

    local timeRemaining = expirationTime - GetTime();

    -- Handle flashing
    if (timeRemaining and timeRemaining < _G.BUFF_WARNING_TIME) then
        local alphaValue;

        if (self.isPulsing == 1) then
            alphaValue = (_G.BUFF_FLASH_TIME_ON - self.pulseTime) / _G.BUFF_FLASH_TIME_ON;
        else
            alphaValue = self.pulseTime / _G.BUFF_FLASH_TIME_ON;
        end

        alphaValue = (alphaValue * (1 - _G.BUFF_MIN_ALPHA)) + _G.BUFF_MIN_ALPHA;

        self:SetAlpha(alphaValue);
    else
        self:SetAlpha(1.0);
    end
end

local function AuraButton_OnUpdate(self)
    local _, _, count, _, duration, expirationTime, _, _, _,
        _, _, _, _, _, timeMod = UnitAura("player", self:GetID(), self.filter);

    if (not count or count < 1) then
        self.countText:SetText(tk.Strings.Empty);
    else
        self.countText:SetText(count);
    end

    if (not expirationTime) then
        return;
    end

    local timeRemaining = expirationTime - GetTime();

    if (timeRemaining > 0) then
        if (timeMod > 0) then
            timeRemaining = timeRemaining / timeMod;
        end

        self.timeRemaining = timeRemaining;
        self.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(timeRemaining));

        if (self.statusBar) then
            self.statusBar:SetValue(timeRemaining);
            self.statusBar:SetMinMaxValues(0, duration);
        end
    else
        self.timeRemaining = nil;
        self.timeRemainingText:SetText(tk.Strings.Empty);
    end
end

local function AuraEnchantButton_OnUpdate(self, btn, globalName)
    local index = tk.Tables:IndexOf(enchantAuraIds, btn:GetID());
    local hasEnchant, expirationTime, count = select(ARGS_PER_ITEM * (index - 1) + 1, GetWeaponEnchantInfo());

    if (not (hasEnchant and expirationTime and count)) then
        if (btn.isEnchantActive) then
            btn.isEnchantActive = nil;
            -- enable/disable auraButtons:
            em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
        end

        return;
    end

    if (self.timeSinceLastUpdate > 1 or btn.forceUpdate) then
        btn.forceUpdate = nil;

        if (count < 1) then
            btn.countText:SetText(tk.Strings.Empty);
        else
            btn.countText:SetText(count);
        end

        if (expirationTime) then
            expirationTime = expirationTime / 1000;
            btn.timeRemaining = expirationTime;
            btn.timeRemainingText:SetFormattedText(SecondsToTimeAbbrev(expirationTime));
        else
            btn.timeRemaining = nil;
            btn.timeRemainingText:SetText(tk.Strings.Empty);
        end
    end

    -- ensure that PLAYER_ENTERING_WORLD works for enchants
    if (not btn.isEnchantActive) then
        btn.isEnchantActive = true;
        -- enable/disable auraButtons:
        em:FindEventHandlerByKey(globalName.."Handler"):Run("UNIT_AURA");
    end
end

-- should only handle updating time remaining and counts
local function AuraArea_OnUpdate(self, elapsed, auraButtons, enchantButtons, pulse)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    for _, btn in ipairs(auraButtons) do
        if (btn.filter == "HELPFUL" and pulse) then
            AuraButton_UpdateAlpha(btn, elapsed);
        end

        if (self.timeSinceLastUpdate > 1 or btn.forceUpdate) then
            btn.forceUpdate = nil;
            AuraButton_OnUpdate(btn);
        end
    end

    if (enchantButtons) then
        for _, btn in ipairs(enchantButtons) do
            AuraEnchantButton_OnUpdate(self, btn, self:GetName());
        end
    end

    if (self.timeSinceLastUpdate > 1) then
        self.timeSinceLastUpdate = 0;
    end
end

-- local function SetBorderShown(data, shown)
--     if (not data.backdrop and not shown) then
--         return;
--     end

--     local borderSize = 0; -- must be 0 in case it needs to be disabled

--     if (shown) then
--         if (not data.backdrop) then
--             data.backdrop = obj:PopTable();
--         end

--         local borderType = data.sharedSettings.border.type;
--         local borderColor = data.sharedSettings.colors.border;
--         borderSize = data.sharedSettings.border.size;

--         data.backdrop.edgeFile = tk.Constants.LSM:Fetch("border", borderType);
--         data.backdrop.edgeSize = borderSize;

--         data.frame:SetBackdrop(data.backdrop);
--         data.frame:SetBackdropBorderColor(unpack(borderColor));

--         if (data.iconFrame) then
--             data.iconFrame:SetBackdrop(data.backdrop);
--             data.iconFrame:SetBackdropBorderColor(unpack(borderColor));
--         end
--     else
--         data.frame:SetBackdrop(nil);
--         data.iconFrame:SetBackdrop(nil);
--     end

--     SetWidgetBorderSize(data.slider, borderSize);

--     if (data.iconFrame and data.settings.showIcons) then
--         data.iconFrame:SetPoint("TOPRIGHT", data.frame, "TOPLEFT", -(borderSize * 2) - ICON_GAP, 0);
--         data.iconFrame:SetPoint("BOTTOMRIGHT", data.frame, "BOTTOMLEFT", -(borderSize * 2) - ICON_GAP, 0);
--         SetWidgetBorderSize(data.icon, borderSize);

--         local barWidthWithIconAndBorder = data.frame:GetWidth() - (borderSize * 2);
--         data.frame:SetWidth(barWidthWithIconAndBorder);
--     end
-- end

-- Stack ---------------------------

local function CancelAura(self)
    if (InCombatLockdown()) then
        return; -- cannot cancel buffs in combat due to protected blizzard utf8.codepoint(
    end

    if (self.filter) then
        -- it is a standard aura
        CancelUnitBuff("player", self:GetID(), self.filter);
    end
end

auraStack:OnNewItem(function(parent, auraID, settings, filter)
    local btn = CreateFrame("Button", nil, parent);
    btn:SetFrameLevel(20);
    btn:SetID(auraID);
    btn.filter = filter;

    if (filter == "HELPFUL") then
        btn:RegisterForClicks("RightButtonUp");
        btn:SetScript("OnClick", CancelAura)
    end

    btn:SetScript("OnEnter", AuraButton_OnEnter);
    btn:SetScript("OnLeave", tk.GeneralTooltip_OnLeave);

    btn.iconTexture = btn:CreateTexture(nil, "ARTWORK");
    btn.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    btn.timeRemainingText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");

    if (settings.statusBars.enabled) then
        btn.statusBar = CreateFrame("StatusBar", nil, btn);
        btn.statusBar:SetFrameLevel(10);
        btn.auraNameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    end

    btn.background = tk:SetBackground(btn.statusBar or btn, 0, 0, 0);
    UpdateAuraButtonAppearance(settings, btn);

    return btn;
end);

-- C_AuraArea ----------------------

Engine:DefineParams("table", "string");
function C_AuraArea:__Construct(data, moduleSettings, areaName)
    data.settings = moduleSettings[areaName];
    data.globalName = string.format("MUI_%sArea", areaName);
    data.auraButtons = obj:PopTable();
    data.enchantButtons = false;
    data.areaName = areaName;

    if (areaName == "Buffs") then
        data.enchantButtons = obj:PopTable();
        data.totalAuras = BUFF_MAX_DISPLAY;
        data.filter = "HELPFUL";
    else
        data.totalAuras = DEBUFF_MAX_DISPLAY;
        data.filter = "HARMFUL";
    end
end

function C_AuraArea:UpdateSize(data)
    if (data.settings.statusBars.enabled) then
        local bars = data.settings.statusBars;

        data.frame:SetSize(bars.width, ((bars.height + bars.spacing) * data.totalAuras) - bars.spacing);
    else
        local icons = data.settings.icons;
        local maxColumns;

        if (data.enchantButtons) then
            maxColumns = math.ceil((data.totalAuras + 1) / icons.perRow);
        else
            maxColumns = math.ceil((data.totalAuras) / icons.perRow);
        end

        data.frame:SetSize(
            ((icons.auraSize + icons.colSpacing) * icons.perRow) - icons.colSpacing,
            ((icons.auraSize + icons.rowSpacing) * maxColumns) - icons.rowSpacing);
    end
end

Engine:DefineParams("boolean")
function C_AuraArea:SetEnabled(data, enabled)
    if (not data.frame and not enabled) then
        return;
    end

    if (enabled) then
        if (not data.frame) then
            data.frame = CreateFrame("Frame", data.globalName);

            if (data.enchantButtons) then
                for index, enchantID in ipairs(enchantAuraIds) do
                    data.enchantButtons[index] = auraStack:Pop(data.frame, enchantID, data.settings, false);
                    data.enchantButtons[index]:Hide();
                end
            end

            self:UpdateSize();

            -- Can I shorten this?
            em:CreateUnitEventHandlerWithKey("UNIT_AURA", data.globalName.."Handler", AuraArea_OnEvent, "Player")
                :SetCallbackArgs(self, data)
                :AppendEvent("GROUP_ROSTER_UPDATE")
                :AppendEvent("PLAYER_ENTERING_WORLD");
        end

        data.frame.timeSinceLastUpdate = 0;
        data.frame:SetScript("OnUpdate", function(self, elapsed)
            AuraArea_OnUpdate(self, elapsed, data.auraButtons, data.enchantButtons, data.settings.pulse);
        end);

        data.frame:SetParent(UIParent);
        data.frame:SetPoint(unpack(data.settings.position));
    else
        em:DestroyEventHandlerByKey(data.globalName.."Handler");
        data.frame:SetScript("OnUpdate", nil);
        data.frame:SetParent(tk.Constants.DUMMY_FRAME);
        data.frame:SetAllPoints(tk.Constants.DUMMY_FRAME);
    end

    data.frame:SetShown(enabled);
    data.enabled = enabled;
end

local function SortByTimeRemaining(a, b)
    if (not (a and b)) then
        return true;
    end

    if (not a.timeRemaining and b.timeRemaining) then
        return true;
    end

    if (a.timeRemaining and not b.timeRemaining) then
        return false;
    end

    if (not a.timeRemaining and not b.timeRemaining) then
        return false;
    end

    return a.timeRemaining > b.timeRemaining;
end

function C_AuraArea:RefreshAnchors(data)
    local totalPositioned = 0;
    local activeButons = obj:PopTable();

    for _, auraBtn in ipairs(data.auraButtons) do
        auraBtn:ClearAllPoints();

        if (auraBtn:IsShown()) then
            table.insert(activeButons, auraBtn);
        end
    end

    table.sort(activeButons, SortByTimeRemaining);

    if (data.enchantButtons) then
        for id, enchantBtn in ipairs(data.enchantButtons) do
            enchantBtn:ClearAllPoints();

            if (enchantBtn:IsShown()) then
                table.insert(activeButons, id, enchantBtn);
            end
        end
    end

    for id, auraBtn in ipairs(activeButons) do
        if (not auraBtn:IsShown()) then
            break;
        end

        if (data.settings.statusBars.enabled) then
            local bars = data.settings.statusBars;

            if (id == 1) then
                if (bars.growDirection == "DOWN") then
                    auraBtn:SetPoint("TOP");
                elseif (bars.growDirection == "UP") then
                    auraBtn:SetPoint("BOTTOM");
                end

            else
                if (bars.growDirection == "DOWN") then
                    auraBtn:SetPoint("TOP", activeButons[id - 1], "BOTTOM", 0, -bars.spacing);
                elseif (bars.growDirection == "UP") then
                    auraBtn:SetPoint("BOTTOM", activeButons[id - 1], "TOP", 0, bars.spacing);
                end
            end
        else
            local icons = data.settings.icons;

            if (id == 1) then
                if (data.settings.icons.growDirection == "LEFT") then
                    auraBtn:SetPoint("TOPRIGHT");
                elseif (icons.growDirection == "RIGHT") then
                    auraBtn:SetPoint("TOPLEFT");
                end

            elseif (totalPositioned % icons.perRow == 0) then
                local anchor = activeButons[(totalPositioned - icons.perRow) + 1];
                auraBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -icons.rowSpacing);

            elseif (icons.growDirection == "LEFT") then
                auraBtn:SetPoint("RIGHT", activeButons[id - 1], "LEFT", -icons.colSpacing, 0);
            elseif (icons.growDirection == "RIGHT") then
                auraBtn:SetPoint("LEFT", activeButons[id - 1], "RIGHT", icons.colSpacing, 0);
            end
        end



        totalPositioned = totalPositioned + 1;
    end

    obj:PushTable(activeButons);
end

-- function C_AuraArea:UpdateAppearance(data)
--     for _, btn in ipairs(data.auraButtons) do
--         if (btn:IsShown()) then
--             UpdateAuraButtonAppearance(data.settings, btn);
--         end
--     end

--     if (data.enchantButtons) then
--         for _, btn in ipairs(data.enchantButtons) do
--             if (btn:IsShown()) then
--                 UpdateAuraButtonAppearance(data.settings, btn);
--             end
--         end
--     end

--     self:UpdateSize();
-- end

-- C_AurasModule -----------------------
function C_AurasModule:OnInitialize(data)
    data.auraAreas = obj:PopTable();

    for _, barName in obj:IterateArgs("Buffs", "Debuffs") do
        local sv = db.profile.auras[barName]; ---@type Observer
        sv:SetParent(db.profile.auras.__templateAuraArea);
    end

    -- local function RefreshAnchors(_, keyName, auraArea, areaName)
    --     if (auraArea) then
    --         local settingName = keyName:PopFront();

    --         if (settingName == "position") then
    --             local frame = auraArea:GetFrame();
    --             frame:ClearAllPoints();
    --             frame:SetPoint(unpack(data.settings[areaName].position));
    --         else
    --             auraArea:RefreshAnchors();
    --         end

    --     end
    -- end

    -- local function UpdateAppearance(_, _, auraArea)
    --     if (auraArea) then
    --         auraArea:UpdateAppearance();
    --     end
    -- end

    local options = {
        onExecuteAll = {
            first = {
                "Buffs.enabled";
                "Debuffs.enabled";
            };
            ignore = { ".*" }; -- ignore everything else
        };
        groups = {
            {
                patterns = { ".*" }; -- (i.e. "Buffs.<setting>")

                onPre = function(value, keysList)
                    local auraAreaName = keysList:PopFront();
                    keysList:PopFront();
                    local auraArea = data.auraAreas[auraAreaName]; ---@type C_AuraArea

                    if (value and not auraArea) then
                        auraArea = C_AuraArea(data.settings, auraAreaName);
                        data.auraAreas[auraAreaName] = auraArea;
                    end

                    return auraArea, auraAreaName;
                end;

                value = {
                    enabled = function(value, _, auraArea, areaName)
                        if (auraArea) then
                            auraArea:SetEnabled(value, areaName);
                        end
                    end;
                    -- position = RefreshAnchors;
                    -- appearance = UpdateAppearance;
                    -- showPulseEffect = function(value, _, auraArea)
                    --     if (not value) then
                    --         local areaData = data:GetFriendData(auraArea);

                    --         for _, btn in ipairs(areaData.auraButtons) do
                    --             btn:SetAlpha(1);
                    --         end
                    --     end
                    -- end;
                }
            };
        };
    };

    self:RegisterUpdateFunctions(db.profile.auras, {}, options);

    -- Hide Blizzard frames
    tk:KillElement(_G.BuffFrame);
    tk:KillElement(_G.TemporaryEnchantFrame);

    self:SetEnabled(true);
end