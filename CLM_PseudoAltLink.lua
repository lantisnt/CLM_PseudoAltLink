local _, PRIV = ...

PRIV.MODULES = {}
PRIV.MODELS = {}
PRIV.GUI = {}
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

local function SetEnabled(self, value)
    self.config.enabled = value and true or false
end

local function GetEnabled(self)
    return self.config.enabled
end

local function InitializeConfigs(self)
    local options = {
        enable = {
            name = "Enable",
            type = "toggle",
            set = function(i, v) SetEnabled(self, v) end,
            get = function(i) return GetEnabled(self) end,
            width = "full",
            order = 1
        },
    }

    CLM.MODULES.ConfigManager:Register(PRIV.CONSTANTS.PLINK, options)
end

function PseudoLink:Initialize()
    InitializeConfigs(self)
    self.config = InitializeDB("config")
    self.ruleset = InitializeDB("ruleset")
end

CLM.MODULES.ConfigManager:AddGroup(PRIV.CONSTANTS.PLINK, true)
CLM.RegisterExternal("PRIV.CONSTANTS.PLINK", PseudoLink)