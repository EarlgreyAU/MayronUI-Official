

-- luacheck: ignore self 143 631
local _G = _G;
local MayronUI = _G.MayronUI;
local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents(); -- luacheck: ignore

---@class QuestTracker : BaseModule
local C_QuestTracker = MayronUI:RegisterModule("QuestTrackerModule", "Quest Tracker", true);

MayronUI:Hook("SideBarModule", "OnInitialize", function(sideBarModule)
    MayronUI:ImportModule("QuestTrackerModule"):Initialize(sideBarModule);
end);

local QuestWatchFrame, IsInInstance, UIParent, hooksecurefunc, ipairs =
    _G.QuestWatchFrame, _G.IsInInstance, _G.UIParent, _G.hooksecurefunc, _G.ipairs;

db:AddToDefaults("profile.questTracker", {
    enabled = true;
    anchoredToSideBars = true;
    width = 250;
    height = 600;
    yOffset = 0;
    xOffset = -30;
});

function C_QuestTracker:OnInitialize(data, sideBarModule)
    data.panel = sideBarModule:GetPanel();

    local function SetUpAnchor()
        data.objectiveContainer:ClearAllPoints();

        if (data.settings.anchoredToSideBars) then
            data.objectiveContainer:SetPoint("TOPRIGHT", data.panel, "TOPLEFT", data.settings.xOffset, data.settings.yOffset);
        else
            data.objectiveContainer:SetPoint("CENTER", data.settings.xOffset, data.settings.yOffset);
        end
    end

    self:RegisterUpdateFunctions(db.profile.questTracker, {
        width = function(value)
            data.objectiveContainer:SetSize(value, data.settings.height);
        end;

        height = function(value)
            data.objectiveContainer:SetSize(data.settings.width, value);
        end;

        anchoredToSideBars = SetUpAnchor;
        yOffset = SetUpAnchor;
        xOffset = SetUpAnchor;
    });

    if (data.settings.enabled) then
        self:SetEnabled(true);
    end
end

function C_QuestTracker:OnEnable(data)
    if (not data.objectiveContainer) then
        -- holds and controls blizzard objectives tracker frame
        data.objectiveContainer = _G.CreateFrame("Frame", nil, UIParent);

        -- blizzard objective tracker frame global variable
        QuestWatchFrame:SetClampedToScreen(false);
        QuestWatchFrame:SetParent(data.objectiveContainer);
        QuestWatchFrame:SetAllPoints(true);

        QuestWatchFrame.ClearAllPoints = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetParent = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetPoint = tk.Constants.DUMMY_FUNC;
        QuestWatchFrame.SetAllPoints = tk.Constants.DUMMY_FUNC;
    end
end