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
            enable = {
                name = "Enable",
                type = "toggle",
                set = function(i, v) self.config[uid].enabled = v and true or false end,
                get = function(i) return self.config[uid].enabled end,
                width = 2,
                order = 1
            },
            manual_raid_awards = {
                name = CLM.L["Manual Raid Awards"],
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
            ruleset = {
                name = "Ruleset",
                type = "header",
                order = 6,
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

    local order = 7
    for ruleset_id in ipairs(self.ruleset[uid] or {}) do
        opt.args["left_" .. ruleset_id] = {
            name = "",
            type = "select",
            values = profileNameMap,
            sorting = profileList,
            set = function(i, v)
                if self.ruleset[uid][ruleset_id].r == v or players_cache[v] then return end
                self.ruleset[uid][ruleset_id].l = v
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

local function pseudoLinkAwardCallback(raid, value, reason, action, note, pointChangeType, forceInstant)

end

hooksecurefunc(CLM.MODULES.PointManager, "UpdateRaidPoints", pseudoLinkAwardCallback)

CLM.MODULES.ConfigManager:AddGroup(PRIV.CONSTANTS.PLINK, true)
CLM.RegisterExternal(PRIV.CONSTANTS.PLINK, PseudoLink)