local _, PRIV = ...

PRIV.CONSTANTS = {}

local CLM = LibStub("ClassicLootManager").CLM
local UTILS = CLM.UTILS

PRIV.CONSTANTS.PLINK = "Pseudo Link"

local PseudoLink = {}

local function InitializeDB(key)
    local db = CLM.MODULES.Database:Server()
    if not db.pseudolink then
        db.pseudolink = {}
    end
    if not db.pseudolink[key] then
        db.pseudolink[key] = { }
    end
    return db.pseudolink[key]
end

local options = {}
local players_cache = {}
local refreshFn = function(_) end
local function GenerateConfigs(self, name, uid)
    local opt = {
        type = "group",
        name = name,
        -- childGroups = "select",
        order = uid,
        args = {
            note = {
                type = "description",
                name = [=[This is a tailored plugin for very specific use case, where players need to gain EP/DKP on multiple characters while being able to spend it separately. Be sure to use only mains  when pseudo-linking so proper CLM alt-main linking can be utilized properly.
Be also sure to check for any discrepancies after changing options / linking w.r.t. raid as this plugin will not be affected retroactively. It will create new events to handle the proper point updates.
Plugin can be activated on raid creation or manually through /clm pseudolink. It will be deactivated automatically after 6 hours.]=],
                width = "full",
                order = 0
            },
            enable = {
                name = "Enable",
                type = "toggle",
                set = function(i, v) self.config[uid].enabled = v and true or false end,
                get = function(i) return self.config[uid].enabled end,
                width = 1,
                order = 1
            },
            manual_raid_awards = {
                name = CLM.L["Manual Raid Awards"],
                desc = "Warning: This toogle does not apply when selecting award type of: On Time Bonus, Boss Kill Bonus or Raid Completion Bonus, Interval Bonus but the specific ones are use",
                type = "toggle",
                set = function(i, v) self.config[uid].manual_raid_awards = v and true or false end,
                get = function(i) return self.config[uid].manual_raid_awards end,
                width = 1,
                order = 2
            },
            boss_kill_bonus = {
                name = CLM.L["Boss Kill Bonus"],
                type = "toggle",
                set = function(i, v) self.config[uid].boss_kill_bonus = v and true or false end,
                get = function(i) return self.config[uid].boss_kill_bonus end,
                width = 1,
                order = 3
            },
            on_time_bonus = {
                name = CLM.L["On Time Bonus"],
                type = "toggle",
                set = function(i, v) self.config[uid].on_time_bonus = v and true or false end,
                get = function(i) return self.config[uid].on_time_bonus end,
                width = 1,
                order = 4
            },
            raid_completion_bonus = {
                name = CLM.L["Raid Completion Bonus"],
                type = "toggle",
                set = function(i, v) self.config[uid].raid_completion_bonus = v and true or false end,
                get = function(i) return self.config[uid].raid_completion_bonus end,
                width = 1,
                order = 5
            },
            interval_bonus = {
                name = CLM.L["Interval Bonus"],
                type = "toggle",
                set = function(i, v) self.config[uid].interval_bonus = v and true or false end,
                get = function(i) return self.config[uid].interval_bonus end,
                width = 1,
                order = 6
            },
            ruleset = {
                name = "Ruleset",
                type = "header",
                order = 7,
                width = "full"
            }
        },
    }

    local roster = CLM.MODULES.RosterManager:GetRosterByUid(uid)
    local profiles, profileNameMap, profileList = {}, {}, {}
    if roster then
        profiles = roster:Profiles()
        for _, GUID in ipairs(profiles) do
            local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
            if profile then
                profileNameMap[profile:Name()] = UTILS.ColorCodeText(profile:Name(), UTILS.GetClassColor(profile:Class()).hex)
                profileList[#profileList + 1] = profile:Name()
            end
        end
        table.sort(profileList)
    end

    local order = 8
    for ruleset_id in ipairs(self.ruleset[uid] or {}) do
        opt.args["left_" .. ruleset_id] = {
            name = "",
            type = "select",
            values = profileNameMap,
            sorting = profileList,
            set = function(i, v)
                if self.ruleset[uid][ruleset_id].r == v or players_cache[v] then return end
                self.ruleset[uid][ruleset_id].l = v
                self.twoWayMap = nil -- Reset the map to force lazy rebuild
            end,
            get = function(i) return self.ruleset[uid][ruleset_id].l end,
            width = 1.35,
            order = order
        }
        order = order + 1
        opt.args["right_" .. ruleset_id] = {
            name = "",
            type = "select",
            values = profileNameMap,
            sorting = profileList,
            set = function(i, v)
                if self.ruleset[uid][ruleset_id].l == v or players_cache[v] then return end
                self.ruleset[uid][ruleset_id].r = v
                self.twoWayMap = nil -- Reset the map to force lazy rebuild
            end,
            get = function(i) return self.ruleset[uid][ruleset_id].r end,
            width = 1.35,
            order = order
        }
        order = order + 1
        opt.args["remove_" .. ruleset_id] = {
            name = "",
            type = "execute",
            width = 0.2,
            image = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
            func = function()
                tremove(self.ruleset[uid], ruleset_id)
                self.twoWayMap = nil -- Reset the map to force lazy rebuild
                refreshFn(self)
            end,
            order = order
        }
        order = order + 1
    end

    opt.args["left_next"] = {
        name = "Add New",
        type = "select",
        values = profileNameMap,
        sorting = profileList,
        set = function(i, v)
            if players_cache[v] then return end
            if not self.ruleset[uid] then self.ruleset[uid] = {} end
            table.insert(self.ruleset[uid], {l = v, r = ""})
            refreshFn(self)
        end,
        get = function(i) return end,
        width = 1.35,
        order = order
    }
    order = order + 1

    return opt
end

local function UpdateConfigs(self)
    for uid, name in pairs(CLM.MODULES.RosterManager:GetRostersUidMap()) do
        if not self.config[uid] then
            self.config[uid] = {}
        end
        for _, ruleset in ipairs(self.ruleset[uid] or {}) do
            players_cache[ruleset.l or ""] = true
            players_cache[ruleset.r or ""] = true
        end
        options[name] = GenerateConfigs(self, name, uid)
    end
    CLM.MODULES.ConfigManager:Register(PRIV.CONSTANTS.PLINK, options, true)
end
refreshFn = UpdateConfigs

function PseudoLink:Initialize()
    self.config = InitializeDB("config")
    self.ruleset = InitializeDB("ruleset")

    UpdateConfigs(self)

    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        UpdateConfigs(self)
        CLM.MODULES.ConfigManager:UpdateOptions(PRIV.CONSTANTS.PLINK)
    end)
end

local function BuildTwoWayMap(self, uid)
    if self.twoWayMap then return true end
    if #self.ruleset[uid] == 0 then return false end
    self.twoWayMap = {}
    for _, rule in ipairs(self.ruleset[uid]) do
        if rule.l and rule.l ~= "" and rule.r and rule.r ~= "" and rule.l ~= rule.r then
            self.twoWayMap[rule.l] = rule.r
            self.twoWayMap[rule.r] = rule.l
        end
    end
    return true
end

function PseudoLink:IsEnabled(rosterUid)
    --return (self.config[rosterUid] or {}).enabled and (GetServerTime() - (self.config.startTime or 0) < 21600)
    return true
end
function PseudoLink:ManualRaidAwards(rosterUid)
    return (self.config[rosterUid] or {}).manual_raid_awards
end
function PseudoLink:BossKillBonus(rosterUid)
    return (self.config[rosterUid] or {}).boss_kill_bonus
end
function PseudoLink:OnTimeBonus(rosterUid)
    return (self.config[rosterUid] or {}).on_time_bonus
end
function PseudoLink:RaidCompletionBonus(rosterUid)
    return (self.config[rosterUid] or {}).raid_completion_bonus
end
function PseudoLink:IntervalBonus(rosterUid)
    return (self.config[rosterUid] or {}).interval_bonus
end

local function GetSourceDict(raid)
    local source = {}
    local in_raid
    if raid:Configuration():Get("autoAwardIncludeBench") then
        in_raid = raid:AllPlayers()
    else
        in_raid = raid:Players()
    end
    -- Raid targets should be unique list of GUIDs
    local roster = raid:Roster()
    for _,GUID in ipairs(in_raid) do
        local mainProfile = nil
        if not roster:IsProfileInRoster(GUID) then
            CLM.LOG:Debug("CLM PLINK pseudoLinkAward(): Unknown profile guid [%s] in roster [%s]", GUID, roster:UID())
        else
            local targetProfile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
            if targetProfile and not targetProfile:IsLocked() then
                -- Check if we have main-alt linking
                if targetProfile:Main() == "" then -- is main
                    mainProfile = targetProfile
                else -- is alt
                    mainProfile = CLM.MODULES.ProfileManager:GetProfileByGUID(targetProfile:Main())
                end
                if roster:IsProfileInRoster(mainProfile:GUID()) then
                    source[mainProfile:Name()] = mainProfile:GUID()
                end
            end
        end
    end
    return source
end

local function SanitizeSource(self, source)
    for l, r in pairs(self.twoWayMap) do
        if source[l] and source[r] then -- Remove if both sides of the rule are in sources
            source[l] = nil
            source[r] = nil
        end
    end
end

local function GetTargetsList(self, source)
    local targets = {}
    for name,_ in pairs(source) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByName(self.twoWayMap[name])
        if profile then
            targets[#targets+1] = profile
        end
    end
    return targets
end

local function PseudoLinkAward(raid, value, reason, action, note, pointChangeType, forceInstant)
    -- Lazy build map
    if not BuildTwoWayMap(PseudoLink, raid:Roster():UID()) then return end
    -- Build actual source list
    local source = GetSourceDict(raid)
    -- Sanitize source dict
    SanitizeSource(PseudoLink, source)
    -- Get targets
    local targets = GetTargetsList(PseudoLink, source)
    -- Award points
    CLM.MODULES.PointManager:UpdatePoints(raid:Roster(), targets, value, reason, action, note, pointChangeType, forceInstant)
end

local function pseudoLinkAwardCallback(_, raid, value, reason, action, note, pointChangeType, forceInstant)
    if not CLM.CONSTANTS.POINT_MANAGER_ACTION.MODIFY then return end
    if type(value) ~= "number" then return end
    if not UTILS.typeof(raid, CLM.MODELS.Raid) then return end
    if not PseudoLink:IsEnabled() then return end
    local uid = raid:Roster():UID()
    if reason == CLM.CONSTANTS.POINT_CHANGE_REASON.ON_TIME_BONUS then
        if not PseudoLink:OnTimeBonus(uid) then return end
    elseif reason == CLM.CONSTANTS.POINT_CHANGE_REASON.BOSS_KILL_BONUS then
        if not PseudoLink:BossKillBonus(uid) then return end
    elseif reason == CLM.CONSTANTS.POINT_CHANGE_REASON.RAID_COMPLETION_BONUS then
        if not PseudoLink:RaidCompletionBonus(uid) then return end
    elseif reason == CLM.CONSTANTS.POINT_CHANGE_REASON.INTERVAL_BONUS then
        if not PseudoLink:IntervalBonus(uid) then return end
    end
    C_Timer.After(0.250, function()
        PseudoLinkAward(raid, value, reason, action, note, pointChangeType, forceInstant)
    end)
end

hooksecurefunc(CLM.MODULES.PointManager, "UpdateRaidPoints", pseudoLinkAwardCallback)

CLM.MODULES.ConfigManager:AddGroup(PRIV.CONSTANTS.PLINK, true)
CLM.RegisterExternal(PRIV.CONSTANTS.PLINK, PseudoLink)