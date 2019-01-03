-- luacheck: ignore self 143 631
local MayronUI = _G.MayronUI;
local tk, db, em, gui, obj, L = MayronUI:GetAllComponents(); -- luacheck: ignore

local InCombatLockdown, CreateFrame = _G.InCombatLockdown, _G.CreateFrame;
local HasArtifactEquipped, GetWatchedFactionInfo = _G.HasArtifactEquipped, _G.GetWatchedFactionInfo;
local UnitXP, UnitXPMax, GetXPExhaustion = _G.UnitXP, _G.UnitXPMax, _G.GetXPExhaustion;
local C_ArtifactUI, GameTooltip = _G.C_ArtifactUI, _G.GameTooltip;
local GetNumPurchasableArtifactTraits = _G.ArtifactBarGetNumArtifactTraitsPurchasableFromXP;

-- Setup Namespaces ----------------------

local Private = {}; -- needed for dynamically loading correct bar

-- Constants -----------------------------

local BAR_NAMES = {"reputation", "experience", "artifact"};
local REPUTATION_BAR_ID = "reputation";
local EXPERIENCE_BAR_ID = "experience";
local ARTIFACT_BAR_ID = "artifact";

-- Setup Objects -------------------------

local Engine = obj:Import("MayronUI.Engine");

local BottomUIPackage = obj:CreatePackage("BottomUI");
Engine:AddSubPackage(BottomUIPackage);

local C_ResourceBar = BottomUIPackage:CreateClass("ResourceBar", "Framework.System.FrameWrapper");

-- Register and Import Modules -----------

local C_ResourceBarsModule = MayronUI:RegisterModule("BottomUI_ResourceBars", "Resource Bars", true);
local containerModule = MayronUI:ImportModule("BottomUI_Container");

-- Load Database Defaults ----------------

db:AddToDefaults("profile.resourceBars", {
    experienceBar = {
        enabled = true,
        height = 8,
        alwaysShowText = false,
        fontSize = 8,
    },
    reputationBar = {
        enabled = true,
        height = 8,
        alwaysShowText = false,
        fontSize = 8,
    },
    artifactBar = {
        enabled = true,
        height = 8,
        alwaysShowText = false,
        fontSize = 8,
    }
});

-- Private Functions ---------------------

function Private.experienceBar_OnSetup(self, data)
    if (tk:IsPlayerMaxLevel()) then
        self:SetEnabled(false);
        return;
    end

    data.blizzardBar = _G.MainMenuExpBar;

    data.rested = CreateFrame("StatusBar", nil, data.frame);
    data.rested:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", "MUI_StatusBar"));
    data.rested:SetPoint("TOPLEFT", 1, -1);
    data.rested:SetPoint("BOTTOMRIGHT", -1, 1);
    data.rested:SetOrientation("HORIZONTAL");

    data.rested.texture = data.rested:GetStatusBarTexture();
    data.rested.texture:SetVertexColor(0, 0.3, 0.5, 0.3);

    local r, g, b = tk:GetThemeColor();
    data.statusbar.texture:SetVertexColor(r * 0.8, g * 0.8, b  * 0.8);

    em:CreateEventHandler("PLAYER_LEVEL_UP", function(handler, _, level)
        if (tk:GetMaxPlayerLevel() == level) then

            self:SetEnabled(false);
            em:FindHandlerByKey("PLAYER_XP_UPDATE", "xp_bar_update"):Destroy();
            handler:Destroy();

        end
    end);

    local handler = em:CreateEventHandler("PLAYER_XP_UPDATE", function()
        local currentValue = UnitXP("player");
        local maxValue = UnitXPMax("player");
        local exhaustValue = GetXPExhaustion();

        data.statusbar:SetMinMaxValues(0, maxValue);
        data.statusbar:SetValue(currentValue);
        data.rested:SetMinMaxValues(0, maxValue);
        data.rested:SetValue(exhaustValue and (exhaustValue + currentValue) or 0);

        if (data.statusbar.text) then
            local percent = (currentValue / maxValue) * 100;
            currentValue = tk.Strings:FormatReadableNumber(currentValue);
            maxValue = tk.Strings:FormatReadableNumber(maxValue);
            local text = tk.string.format("%s / %s (%d%%)", currentValue, maxValue, percent);
            data.statusbar.text:SetText(text);
        end
    end);

    handler:SetKey("xp_bar_update");
    handler:Run();
end

function Private.experienceBar_ShowText()
    local handler = em:FindHandlerByKey("PLAYER_XP_UPDATE", "xp_bar_update");
    if (handler) then
        handler:Run();
    end
end

function Private.artifactBar_OnSetup(_, data)
    data.blizzardBar = _G.ArtifactWatchBar;
    data.statusbar.texture = data.statusbar:GetStatusBarTexture();
    data.statusbar.texture:SetVertexColor(0.9, 0.8, 0.6, 1);

    local handler = em:CreateEventHandler("ARTIFACT_XP_UPDATE", function()
        local totalXP, pointsSpent, _, _, _, _, _, _, tier = select(5, C_ArtifactUI.GetEquippedArtifactInfo());
        local _, currentValue, maxValue = GetNumPurchasableArtifactTraits(pointsSpent, totalXP, tier);

        data.statusbar:SetMinMaxValues(0, maxValue);
        data.statusbar:SetValue(currentValue);

        if (data.statusbar.text) then
            if currentValue > 0 and maxValue == 0 then
                maxValue = currentValue;
            end

            local percent = (currentValue / maxValue) * 100;
            currentValue = tk.Strings:FormatReadableNumber(currentValue);
            maxValue = tk.Strings:FormatReadableNumber(maxValue);

            local text = string.format("%s / %s (%d%%)", currentValue, maxValue, percent);
            data.statusbar.text:SetText(text);
        end
    end);
    handler:SetKey("artifact_bar_update");

    em:CreateEventHandler("UNIT_INVENTORY_CHANGED", function()
        local equipped = HasArtifactEquipped();
        local bar = self:GetBar(data.barName);

        bar:SetEnabled(not equipped and data.enabled);

        if (equipped) then
            handler:Run();
        end
    end):Run();
end

function Private.artifactBar_ShowText()
    local handler = em:FindHandlerByKey("ARTIFACT_XP_UPDATE", "artifact_bar_update");
    if (handler) then
        handler:Run();
    end
end

function Private.reputationBar_OnSetup(self, data)
    data.statusbar:HookScript("OnEnter", function(self)
        local factionName, standingID, minValue, maxValue, currentValue = GetWatchedFactionInfo();

        if (standingID < 8) then
			maxValue = maxValue - minValue;

			if (maxValue > 0) then
				currentValue = currentValue - minValue;
				local percent = (currentValue / maxValue) * 100;

				currentValue = tk.Strings:FormatReadableNumber(currentValue);
				maxValue = tk.Strings:FormatReadableNumber(maxValue);

				local text = tk.string.format("%s: %s / %s (%d%%)", factionName, currentValue, maxValue, percent);

				GameTooltip:SetOwner(self, "ANCHOR_TOP");
				GameTooltip:AddLine(text, 1, 1, 1);
				GameTooltip:Show();
			end
		end
    end);

    data.statusbar:HookScript("OnLeave", function(self)
        GameTooltip:Hide();
    end);

    data.statusbar.texture = data.statusbar:GetStatusBarTexture();
    data.statusbar.texture:SetVertexColor(0.16, 0.6, 0.16, 1);

    local handler = em:CreateEventHandlers("UPDATE_FACTION, PLAYER_REGEN_ENABLED", function()
        local factionName, standingID, minValue, maxValue, currentValue = GetWatchedFactionInfo();

		if (not InCombatLockdown()) then
			if (not factionName or standingID == 8) then
                self:SetEnabled(false);
                return;

			elseif (not data.enabled) then
				self:SetEnabled(true);
			end
		end

        maxValue = maxValue - minValue;
        currentValue = currentValue - minValue;

        data.statusbar:SetMinMaxValues(0, maxValue);
        data.statusbar:SetValue(currentValue);

        if (data.statusbar.text) then
            local percent = (currentValue / maxValue) * 100;
            currentValue = tk.Strings:FormatReadableNumber(currentValue);
            maxValue = tk.Strings:FormatReadableNumber(maxValue);

            local text = tk.string.format("%s: %s / %s (%d%%)", factionName, currentValue, maxValue, percent);
            data.statusbar.text:SetText(text);
        end
    end);

    handler:SetKey("reputation_bar_update");
    handler:Run();
end

function Private.reputationBar_ShowText()
    local handler = em:FindHandlerByKey("UPDATE_FACTION", "reputation_bar_update");
    if (handler) then
        handler:Run();
    end
end

-- C_ResourceBar ---------------------------

BottomUIPackage:DefineParams("BottomUI_ResourceBars", "Frame", "string");
function C_ResourceBar:__Construct(data, barsModule, barsContainer, barName)
    data.module = barsModule;
    data.barName = barName;
    data.enabled = true;
    data.sv = db.profile.resourceBars[barName.."Bar"];

    local texture = tk.Constants.LSM:Fetch("statusbar", "MUI_StatusBar");
    local frame = CreateFrame("Frame", "MUI_"..data.barName.."Bar", barsContainer);

    frame:SetBackdrop(tk.Constants.backdrop);
    frame:SetBackdropBorderColor(0, 0, 0);
    frame.bg = tk:SetBackground(frame, texture);
    frame.bg:SetVertexColor(0.08, 0.08, 0.08);
    frame:SetHeight(data.sv.height);

    local statusbar = CreateFrame("StatusBar", nil, frame);
    statusbar:SetStatusBarTexture(texture);
    statusbar:SetOrientation("HORIZONTAL");
    statusbar:SetPoint("TOPLEFT", 1, -1);
    statusbar:SetPoint("BOTTOMRIGHT", -1, 1);

    statusbar.texture = statusbar:GetStatusBarTexture();

    statusbar:SetScript("OnEnter", function(self)
        self.texture:SetBlendMode("ADD");
        if (data.blizzardBar) then
            data.blizzardBar:GetScript("OnEnter")(data.blizzardBar);
        end
    end);

    statusbar:SetScript("OnLeave", function(self)
        self.texture:SetBlendMode("BLEND");
        if (data.blizzardBar) then
            data.blizzardBar:GetScript("OnLeave")(data.blizzardBar);
        end
    end);

    statusbar.text = statusbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    statusbar.text:SetPoint("CENTER");
    tk:SetFontSize(statusbar.text, data.sv.fontSize);

    if (not data.sv.alwaysShowText) then
        statusbar.text:Hide();

        statusbar:SetScript("OnEnter", function(self)
            self.text:Show();
        end);

        statusbar:SetScript("OnLeave", function(self)
            self.text:Hide();
        end);
    end

    data.frame = frame;
    data.statusbar = statusbar;

    Private[data.barName.."Bar_ShowText"](self, data);
    Private[barName.."Bar_OnSetup"](self, data);
end

BottomUIPackage:DefineReturns("number");
function C_ResourceBar:GetHeight(data)
    return data.frame:GetHeight();
end

BottomUIPackage:DefineReturns("boolean");
function C_ResourceBar:IsEnabled(data)
    return data.enabled;
end

BottomUIPackage:DefineParams("boolean");
function C_ResourceBar:SetEnabled(data, enabled)
    data.enabled = enabled;
    data.frame:SetShown(enabled);
    data.module:UpdateContainer();
end

-- C_ResourceBarsModule -------------------
function C_ResourceBarsModule:OnInitialize(data, buiContainer)
    data.buiContainer = buiContainer;
    data.sv = db.profile.resourceBars;
    self:SetEnabled(true); -- set module enabled (not bar)
end

function C_ResourceBarsModule:OnEnable(data)
    data.barsContainer = CreateFrame("Frame", "MUI_ResourceBars", data.buiContainer);
    data.barsContainer:SetFrameStrata("MEDIUM");
    data.barsContainer:SetPoint("BOTTOMLEFT", data.buiContainer, "TOPLEFT", 0, -1);
    data.barsContainer:SetPoint("BOTTOMRIGHT", data.buiContainer, "TOPRIGHT", 0, -1);

    data.bars = obj:PopWrapper();

    for _, barName in ipairs(BAR_NAMES) do
        if (data.sv[barName.."Bar"].enabled) then
            local enabled = false;

            if (barName == ARTIFACT_BAR_ID) then
                enabled = HasArtifactEquipped();

            elseif (barName == REPUTATION_BAR_ID) then
                enabled = GetWatchedFactionInfo();

            elseif (barName == EXPERIENCE_BAR_ID) then
                enabled = true; --not tk:IsPlayerMaxLevel();
                -- TODO THIS!
            end

            if (enabled) then
                -- Create Resource Bar here! (enabled by default!)
                data.bars[barName] = C_ResourceBar(self, data.barsContainer, barName);
            end
        end
    end

    self:UpdateContainer();

    MayronUI:Hook("DataText", "OnEnable", function(_, dataTextModuleData)
        if (db.profile.datatext.blockInCombat) then
            self:CreateBlocker(dataTextModuleData.sv, dataTextModuleData.bar);
        end
    end);
end

function C_ResourceBarsModule:UpdateContainer(data)
    local height = 0;
    local previousBar;

    for _, barName in ipairs(BAR_NAMES) do
        if (data.bars[barName]) then
            local bar = data.bars[barName];

            if (bar:IsEnabled()) then
                bar:ClearAllPoints();

                if (not previousBar) then
                    bar:SetPoint("BOTTOMLEFT");
                    bar:SetPoint("BOTTOMRIGHT");
                else
                    local frame = previousBar:GetFrame();
                    bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -1);
                    bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -1);
                    height = height - 1;
                end

                height = height + bar:GetHeight();
                previousBar = bar;
            end
        end
    end

    if (height == 0) then
        height = 1;
    end

    data.barsContainer:SetHeight(height);
    containerModule:UpdateContainer();
end

Engine:DefineReturns("number");
function C_ResourceBarsModule:GetHeight(data)
    return data.barsContainer:GetHeight();
end

Engine:DefineParams("string");
Engine:DefineReturns("Frame");
function C_ResourceBarsModule:GetBar(data, barName)
    return data.bars[barName];
end

function C_ResourceBarsModule:CreateBlocker(data, dataTextSvTable, dataTextBar)
    if (not data.blocker) then

        data.blocker = tk:PopFrame("Frame", data.barsContainer);
        data.blocker:SetPoint("TOPLEFT");
        data.blocker:SetPoint("BOTTOMRIGHT", dataTextBar, "BOTTOMRIGHT");
        data.blocker:EnableMouse(true);
        data.blocker:SetFrameStrata("DIALOG");
        data.blocker:SetFrameLevel(20);
        data.blocker:Hide();

        em:CreateEventHandler("PLAYER_REGEN_DISABLED", function()
            if (not dataTextSvTable.blockInCombat) then return; end
            data.blocker:Show();
        end);

        em:CreateEventHandler("PLAYER_REGEN_ENABLED", function()
            data.blocker:Hide();
        end);
    end

    if (InCombatLockdown()) then
        data.blocker:Show();
    end
end

Engine:DefineReturns("Frame");
function C_ResourceBarsModule:GetBarContainer(data)
    return data.barsContainer;
end