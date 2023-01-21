-- Constants

local FACTIONS = {
    'Horde',
    'Alliance',
    'Unknown'
}
SLASH_PLAYEDEXTENDED1 = '/pe'

-- Defaults

local defaults = {
    data = {}
}


-- Event Handlers and Initialization

local PlaytimeExtended = CreateFrame('Frame')

function PlaytimeExtended:OnEvent(event, ...)
	self[event](self, event, ...)
end

function PlaytimeExtended:ADDON_LOADED(event, addOnName)
    if addOnName == 'PlayedExtended' then
        PlayedExtendedDb = PlayedExtendedDb or {}
        self.db = PlayedExtendedDb

        for k, v in pairs(defaults) do
            if self.db[k] == nil then
                self.db[k] = v
            end
        end
    end
end

function PlaytimeExtended:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReload)
    if isInitialLogin then
        self:GetTimePlayedFromServer()
    end
end

function PlaytimeExtended:PLAYER_LOGOUT(event)
    self:GetTimePlayedFromServer()
end

function PlaytimeExtended:TIME_PLAYED_MSG(event, total, currentLevel)
    self:UpdateTimePlayed(total, currentLevel)
end

PlaytimeExtended:RegisterEvent('ADDON_LOADED')
PlaytimeExtended:RegisterEvent('PLAYER_ENTERING_WORLD')
PlaytimeExtended:RegisterEvent('PLAYER_LOGOUT')
PlaytimeExtended:RegisterEvent('TIME_PLAYED_MSG')
PlaytimeExtended:SetScript('OnEvent', PlaytimeExtended.OnEvent)

-- Addon Code

function PlaytimeExtended:GetTimePlayedFromServer()
    RequestTimePlayed()
end

function PlaytimeExtended:UpdateTimePlayed(total, currentLevel)
    local charName = UnitName('player')	
    local realm = GetRealmName()
    local faction = UnitFactionGroup('player')
    self.db['data'][charName .. '__' .. realm] = AccountPlaytime:new(total, realm, faction, charName)
end

function PlaytimeExtended:CalculatePlaytimeResults()
    local factionResults = {}
    for k, v in pairs(FACTIONS) do 
        factionResults[v] = PlaytimeStats:new()
    end
    local results = {total = PlaytimeStats:new(), perFaction = factionResults, perRealm = {}}

    for character, values in pairs(self.db['data']) do
        results['total']['time'] = results['total']['time'] + values.total
        results['total']['noOfChars'] = results['total']['noOfChars'] + 1

        results['perFaction'][values.faction]['time'] = results['perFaction'][values.faction]['time'] + values.total
        results['perFaction'][values.faction]['noOfChars'] = results['perFaction'][values.faction]['noOfChars'] + 1
        
        if results['perRealm'][values.realm] == nil then
            results['perRealm'][values.realm] = PlaytimeStats:new()
        end
        results['perRealm'][values.realm]['time'] = results['perRealm'][values.realm]['time'] + values.total
        results['perRealm'][values.realm]['noOfChars'] = results['perRealm'][values.realm]['noOfChars'] + 1
    end

    return results
end

function PlaytimeExtended:DisplayPlayed()
    local results = PlaytimeExtended:CalculatePlaytimeResults()

    print('Total played: ' .. GetPlayedInDaysMinutesSeconds(results['total']['time']) .. ' ('..results['total']['noOfChars']..' characters)')
    print('Total played per faction: ')
    for k, v in pairs(FACTIONS) do
        print('    ' .. v .. ': ' .. GetPlayedInDaysMinutesSeconds(results['perFaction'][FACTIONS[k]]['time']) .. ' ('..results['perFaction'][FACTIONS[k]]['noOfChars']..' characters)')
    end
    print('Total played per realm: ')
    for realm, realmData in pairs(results['perRealm']) do
        print('    ' .. realm .. ': ' .. GetPlayedInDaysMinutesSeconds(realmData['time']) .. ' ('..realmData['noOfChars']..' characters)')
    end
end

-- Classes

--[[
    AccountPlaytime
    This class is used to store the playtime data. It has the following values:
    * total = Total playtime of the character in seconds
    * realm = The realm where the character is on
    * faction = The faction of the character
    * charName = The name of the character
--]]
AccountPlaytime = {}
function AccountPlaytime:new(total, realm, faction, charName)
    newAccountPlaytime = {total = total, realm = realm, faction = faction, charName = charName}
    self.__index = self
    return setmetatable(newAccountPlaytime, self)
end


--[[
    PlaytimeStats
    This class is used to calculate the playtime stats for display:
    * time = Total playtime for a given track segment
    * noOfChars = Total number of chars for a given track segment
--]]
PlaytimeStats = {}
function PlaytimeStats:new()
    newPlaytimeStats = {time = 0, noOfChars = 0}
    self.__index = self
    return setmetatable(newPlaytimeStats, self)
end


-- Helpers

function GetPlayedInDaysMinutesSeconds(played)
    days = math.floor(played / 86400)
    hours = math.floor(math.fmod(played, 86400) / 3600)
    minutes = math.floor(math.fmod(math.fmod(played, 86400), 3600) / 60)
    seconds = math.fmod(math.fmod(math.fmod(played, 86400), 3600), 60)

    return days .. ' days, ' .. hours .. ' hours, ' .. minutes .. ' minutes and ' .. seconds .. ' seconds'
end

-- Slash Handler

function SlashHandler(msg, editbox)
    if msg == 'reset' then
        PlayedExtendedDb = {}
        PlaytimeExtended:GetTimePlayedFromServer()
        print('PlayedExtended was reset!')
    else
        PlaytimeExtended:DisplayPlayed()
    end
end

SlashCmdList.PLAYEDEXTENDED = SlashHandler
