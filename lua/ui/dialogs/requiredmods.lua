-- ==========================================================================================
-- * File       : lua/modules/ui/dialogs/requiredmods.lua 
-- * Authors    : FAF Community, KeyBlue
-- * Summary    : Contains UI for displaying the map required mods
-- ==========================================================================================
local Popup = import('/lua/ui/controls/popups/popup.lua').Popup
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Mods = import('/lua/mods.lua')    
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Tooltip  = import('/lua/ui/game/tooltip.lua')
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText


local dialogContent = nil
local popup = nil

MaxNameLength = 40
MaxDescriptionLength = 16
MaxHowtogetLength = 16


local dialogWidth = 700 -- 557
local dialogHeight = 700 -- 602
local modIconSize = 50 --56
local modInfoPosition = modIconSize + 15 --80
local modInfoHeight = modIconSize + 20  --40
-- calculates how many number of mods to show per page based on dialog height
local modsPerPage = math.floor((dialogHeight - 100) / modInfoHeight) -- - 1


local controlList = {}
local controlMap = {}

function CreateDialog(parent, scenario)
    
    dialogContent = Group(parent)
    dialogContent.Width:Set(dialogWidth)
    dialogContent.Height:Set(dialogHeight)
    
    modsDialog = Popup(parent, dialogContent)
    
    -- Title
    local title = UIUtil.CreateText(dialogContent, '<LOC _Required_Mods>Required Mods', 20, UIUtil.titleFont)
    title:SetColor('B9BFB9')
    title:SetDropShadow(true)
    LayoutHelpers.AtHorizontalCenterIn(title, dialogContent, 0)
    LayoutHelpers.AtTopIn(title, dialogContent, 5)
    
    -- SubTitle: display counts of how many mods are enabled.
    subtitle = UIUtil.CreateText(dialogContent, '', 12, 'Arial')
    subtitle:SetColor('B9BFB9')
    subtitle:SetDropShadow(true)
    LayoutHelpers.AtHorizontalCenterIn(subtitle, dialogContent, 0)
    LayoutHelpers.AtTopIn(subtitle, dialogContent, 26)
    UpdateModsCounters(scenario)
    
    -- Save button
    local SaveButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "Ok", -1)
    SaveButton:UseAlphaHitTest(true)
    LayoutHelpers.AtRightIn(SaveButton, dialogContent, 10)
    LayoutHelpers.AtBottomIn(SaveButton, dialogContent, 15)
    SaveButton.OnClick = function(self)
        modsDialog:Close()
    end
    
    controlList = {}

    modsPerPage = math.floor((dialogHeight - 100) / modInfoHeight)

    scrollGroup = Group(dialogContent)

    LayoutHelpers.AtLeftIn(scrollGroup, dialogContent, 2)
    scrollGroup.Top:Set(function() return subtitle.Bottom() + 5 end)
    scrollGroup.Bottom:Set(function() return SaveButton.Top() - 10 end)
    scrollGroup.Width:Set(function() return dialogContent.Width() - 20 end)

    UIUtil.CreateLobbyVertScrollbar(scrollGroup, 1, 0, -10, 10)
    scrollGroup.top = 1

    scrollGroup.GetScrollValues = function(self, axis)
        return 1, table.getn(controlList), self.top, math.min(self.top + modsPerPage - 1, table.getn(controlList))
    end

    scrollGroup.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end

    scrollGroup.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * modsPerPage)
    end

    scrollGroup.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        self.top = math.max(math.min(table.getn(controlList) - modsPerPage + 1 , top), 1)
        self:CalcVisible()
    end

    scrollGroup.CalcVisible = function(self)
        local top = self.top
        local bottom = self.top + modsPerPage
        local visibleIndex = 1
        for index, control in ipairs(controlList) do
            if control.filtered then
                control:Hide()
            elseif visibleIndex < top or visibleIndex >= bottom then
                control:Hide()
                visibleIndex = visibleIndex + 1
            else
                control:Show()
                control.Left:Set(self.Left)
                local i = visibleIndex
                local c = control
                control.Top:Set(function() return self.Top() + ((i - top) * c.Height()) end)
                visibleIndex = visibleIndex + 1
            end
        end
    end
    
    CreateModsList(scrollGroup, scenario)
    
    scrollGroup.HandleEvent = function(self, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then
                lines = -1
            end
            self:ScrollLines(nil, lines)
            return true
        end

        return false
    end
    
    -- local position = 5
    -- local filterGameMods = CreateModsFilter(dialogContent, modsTags.GAME)
    -- Tooltip.AddControlTooltip(filterGameMods, {
        -- text = LOC('<LOC uiunitmanager_01>Filter Game Mods'),
        -- body = LOC('<LOC uiunitmanager_02>Toggle visibility of all game mods in above list of mods.') })
    -- LayoutHelpers.AtLeftIn(filterGameMods, dialogContent, position)
    -- LayoutHelpers.AtBottomIn(filterGameMods, dialogContent, 15)

    -- position = position + 110
    -- local filterUIMods = CreateModsFilter(dialogContent, modsTags.UI)
    -- Tooltip.AddControlTooltip(filterUIMods, {
        -- text = LOC('<LOC uiunitmanager_03>Filter UI Mods'),
        -- body = LOC('<LOC uiunitmanager_04>Toggle visibility of all UI mods in above list of mods.') })
    -- LayoutHelpers.AtLeftIn(filterUIMods, dialogContent, position)
    -- LayoutHelpers.AtBottomIn(filterUIMods, dialogContent, 15)

    
    
    if scenario.MoreInfoLink then
        -- More Info button
        local MoreInfoButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "More Info", -1)
        MoreInfoButton:UseAlphaHitTest(true)
        LayoutHelpers.CenteredLeftOf(MoreInfoButton, SaveButton, 100)
        MoreInfoButton.OnClick = function(self)
            OpenURL(scenario.MoreInfoLink)
        end
    end
    
    local _,missing = CountAvailableMods(scenario)
    if missing > 0 then
        local downloadList = {}
        for _,modgroup in controlList do
            if modgroup.modInfo.missing and modgroup.modInfo.downloadlink then
                table.insert(downloadList, modgroup.modInfo.downloadlink)
            end
        end
        if table.getn(downloadList) > 0 then
            -- More Info button
            local DownloadButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "Download", -1)
            DownloadButton:UseAlphaHitTest(true)
            LayoutHelpers.CenteredLeftOf(DownloadButton, SaveButton, 300)
            DownloadButton.OnClick = function(self)
                for _,link in downloadList do
                    OpenURL(link)
                end
            end
        end
    end

    return modsDialog
end

function CreateModsList(parent, scenario)
    local posCounter = 1
    local available,missing = filterMods(scenario)
    for _,requiredMod in available do
        local modInfo = TryToFindCompleteModInfo(requiredMod)
        CreateListElement(parent, modInfo, posCounter)
        posCounter = posCounter + 1
    end
    for _,requiredMod in missing do
        local modInfo = TryToFindCompleteModInfo(requiredMod)
        CreateListElement(parent, modInfo, posCounter)
        posCounter = posCounter + 1
    end
    
    parent:CalcVisible()
end

function TryToFindCompleteModInfo(requiredModInfo)
    local allMods = Mods.AllMods()
    for _,aMod in allMods do
        if requiredModInfo.uid == aMod.uid then
            return aMod
        end
    end
    requiredModInfo.missing = true
    return requiredModInfo
end

function CreateListElement(parent, modInfo, Pos)
    local group = Group(parent)
    -- changed fixed-size checkboxes to scalable checkboxes
    group.pos = Pos
    group.modInfo = modInfo
    group.bg = Checkbox(group,
        UIUtil.SkinnableFile('/MODS/blank.dds'),
        UIUtil.SkinnableFile('/MODS/single.dds'),
        UIUtil.SkinnableFile('/MODS/single.dds'),
        UIUtil.SkinnableFile('/MODS/double.dds'),
        UIUtil.SkinnableFile('/MODS/disabled.dds'),
        UIUtil.SkinnableFile('/MODS/disabled.dds'),
            'UI_Tab_Click_01', 'UI_Tab_Rollover_01')
    group.bg.Height:Set(modIconSize + 10)
    group.bg.Width:Set(dialogWidth - 15)

    group.Height:Set(modIconSize + 20)
    group.Width:Set(dialogWidth - 20)
    LayoutHelpers.AtLeftTopIn(group, parent, 2, group.Height()*(Pos-1))
    LayoutHelpers.FillParent(group.bg, group)

    if not modInfo.icon or modInfo.icon == '' then
        modInfo.icon = '/textures/ui/common/dialogs/mod-manager/generic-icon_bmp.dds'
    end

    group.icon = Bitmap(group, modInfo.icon)
    group.icon.Height:Set(modIconSize)
    group.icon.Width:Set(modIconSize)
    group.icon:DisableHitTest()
    LayoutHelpers.AtLeftTopIn(group.icon, group, 10, 7)
    LayoutHelpers.AtVerticalCenterIn(group.icon, group)
    
    local name = modInfo.name or "No Title"
    group.name = UIUtil.CreateText(group, name, 14, UIUtil.bodyFont)
    group.name:SetColor('FFE9ECE9')
    group.name:DisableHitTest()
    LayoutHelpers.AtLeftTopIn(group.name, group, modInfoPosition, 5)
    group.name:SetDropShadow(true)

    local description = modInfo.description or "No Description"
    group.desc = MultiLineText(group, UIUtil.bodyFont, 12, 'FFA2A5A2')
    group.desc:DisableHitTest()
    LayoutHelpers.AtLeftTopIn(group.desc, group, modInfoPosition, 25)
    group.desc.Width:Set(group.Width() - group.icon.Width()-50)
    group.desc:SetText(description)

    group.type = UIUtil.CreateText(group, '', 12, 'Arial Narrow Bold')
    group.type:DisableHitTest()
    group.type:SetColor('B9BFB9')
    group.type:SetFont('Arial Black', 11)
    group.ui = modInfo.ui_only
    if modInfo.missing then
        group.type:SetText(LOC('Missing'))
        group.name:SetColor('FFFF0000')
        group.type:SetColor('FFFF0000')
    else
        group.type:SetText(LOC('Available'))
        group.name:SetColor('FF00FF00')
        group.type:SetColor('FF00FF00')
    end
    LayoutHelpers.AtRightTopIn(group.type, group, 12, 4)
    
    LayoutHelpers.DepthUnderParent(group, parent)
    
    table.insert(controlList, group)
    controlMap[modInfo.uid] = group

    -- Disable all mouse interactivity with the control, but don't _disable_ it, as that alters
    -- what it looks like.
    group.bg.HandleEvent = function() return true end


    return group
end

function UpdateModsCounters(scenario)
    local available, missing = CountAvailableMods(scenario)
    subtitle:SetText(LOCF("<LOC ...>%d available mods and %d missing mods", available, missing))
end

function filterMods(scenario)
    local available = {}
    local missing = {}
    local allMods = Mods.AllMods()
    for _,mod in scenario.RequiredMods do
        local present = false
        for _,aMod in allMods do
            if mod.uid == aMod.uid then
                present = true
                break
            end
        end
        if present then
            table.insert(available, mod)
        else
            table.insert(missing, mod)
        end
    end
    
    return available, missing
end

function IsPlayable(scenario)
    if scenario.RequiredMods then
        local allMods = Mods.AllMods()
        for _,mod in scenario.RequiredMods do
            local present = false
            for _,aMod in allMods do
                if mod.uid == aMod.uid then
                    present = true
                    break
                end
            end
            if not present then
                return false
            end
        end
    end
    return true
end

function CountAvailableMods(scenario)
        
    local availableCount = 0
    local modMissing = false
    local availableMods = Mods.AllMods()
    for _,mod in scenario.RequiredMods do
        
        for _,aMod in availableMods do
            if mod.uid == aMod.uid then
                availableCount = availableCount + 1
                break
            end
        end
    end
    return availableCount, (table.getn(scenario.RequiredMods) - availableCount)
end

function CreateInitialDialog(parent, scenario)
    UIUtil.QuickDialog(parent, "You're missing mods required for this map",
                            "More Info", function() import("/lua/ui/dialogs/requiredmods.lua").CreateDialog(parent, scenario)  end,
                            "<LOC _OK>", nil,
                            nil, nil,
                            true,
                            {escapeButton = 2, enterButton = 2})
end