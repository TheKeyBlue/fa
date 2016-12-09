local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')
local Prefs = import('/lua/user/prefs.lua')

local Reclaim = {}

-- Stores/updates the list of reclaimable props using EntityId as key
-- called from /lua/UserSync.lua
function UpdateReclaim(synctable)
    Reclaim = synctable.Alive -- Set the table to the latest sim state

    local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
    for id, bool in synctable.ToKill do
        local label = view.ReclaimGroup.ReclaimLabels[id]
        if label then -- There exists a label for this id. Kill it.
            label:Destroy()
            view.ReclaimGroup.ReclaimLabels[id] = nil
            label = nil
        end

        if Reclaim[id] then
            WARN('ERROR - The UI Reclaim table has an entry that should have been removed. Investigate ' .. id)
        end
    end

    SimCallback({Func = 'ResetToKill'})
end

local MAX_ON_SCREEN = 1000

local ZoomHide = false
local OldZoom
local NumVisible = 0

function OnScreen(view, pos)
    local proj = view:Project(Vector(pos[1], pos[2], pos[3]))
    return not (proj.x < 0 or proj.y < 0 or proj.x > view.Width() or proj.y > view:Height())
end

local WorldLabel = Class(Group) {
    __init = function(self, parent, position)
        Group.__init(self, parent)
        self.parent = parent
        self.proj = nil
        if position then self:SetPosition(position) end

        self.Top:Set(0)
        self.Left:Set(0)
        self.Width:Set(25)
        self.Height:Set(25)
        self:SetNeedsFrameUpdate(true)
    end,

    Update = function(self)
    end,

    SetPosition = function(self, position)
        self.position = position
    end,

    OnFrame = function(self, delta)
        self:Update()
    end
}

function CreateReclaimLabel(view, data, id)
    local pos = data.position
    local label = WorldLabel(view, Vector(pos[1], pos[2], pos[3]))

    label.mass = Bitmap(label)
    label.mass:SetTexture(UIUtil.UIFile('/game/build-ui/icon-mass_bmp.dds'))
    LayoutHelpers.AtLeftIn(label.mass, label)
    LayoutHelpers.AtVerticalCenterIn(label.mass, label)
    label.mass.Height:Set(14)
    label.mass.Width:Set(14)

    label.text = UIUtil.CreateText(label, pos[1] .. ' ' .. pos[3] .. ' ' .. id .. ' ' .. data.AssociatedBP, 10, UIUtil.bodyFont)
    label.text:SetColor('ffc7ff8f')
    label.text:SetDropShadow(true)
    LayoutHelpers.AtLeftIn(label.text, label, 16)
    LayoutHelpers.AtVerticalCenterIn(label.text, label)

    label:DisableHitTest(true)
    label.Update = function(self)
        local view = self.parent.view
        local proj = view:Project(pos)
        LayoutHelpers.AtLeftTopIn(self, self.parent, proj.x - self.Width() / 2, proj.y - self.Height() / 2 + 1)
        self.proj = {x=proj.x, y=proj.y}
    end

    label:Update()

    return label
end

function UpdateLabels()
    local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
    local n_visible = 0

    for id, data in Reclaim do
        local label = view.ReclaimGroup.ReclaimLabels[id] -- nil if not set yet

        if OnScreen(view, data.position) then -- Only create/show things that are on screen right now
            if not label then -- Create and assign one
                label = CreateReclaimLabel(view.ReclaimGroup, data, id)
                view.ReclaimGroup.ReclaimLabels[id] = label
            else
                label:Show()
            end

            n_visible = n_visible + 1
        elseif label then -- Don't show labels off the screen
            label:Hide()
        end

        --if data.mass ~= label.text:GetText() then
            --label.text:SetText(data.mass)
        --end
    end

    NumVisible = n_visible

    return view.ReclaimGroup.ReclaimLabels
end

local ReclaimThread
function ShowReclaim(show)
    local view = import('/lua/ui/game/worldview.lua').viewLeft

    if show then
        view.ShowingReclaim = true
        if not view.ReclaimThread then
            view.ReclaimThread = ForkThread(ShowReclaimThread)
        end
    else
        view.ShowingReclaim = false
    end
end

function InitReclaimGroup(view)
    if not view.ReclaimGroup or IsDestroyed(view.ReclaimGroup) then
        local rgroup = Group(view)
        rgroup.view = view
        rgroup:DisableHitTest()
        LayoutHelpers.FillParent(rgroup, view)
        rgroup:Show()
        rgroup.ReclaimLabels = {}

        view.ReclaimGroup = rgroup

        rgroup.OnFrame = function(self, delta)
            if view.zoomed and NumVisible > MAX_ON_SCREEN then
                ZoomHide = true
                self:Hide()
            end
        end

        rgroup:SetNeedsFrameUpdate(true)
    else
        view.ReclaimGroup:Show()
    end

end

function ShowReclaimThread(watch_key)
    local i = 0
    local view = import('/lua/ui/game/worldview.lua').viewLeft
    local camera = GetCamera("WorldCamera")

    InitReclaimGroup(view)

    while view.ShowingReclaim and (not watch_key or IsKeyDown(watch_key)) do
        if not view or IsDestroyed(view) then
            view = import('/lua/ui/game/worldview.lua').viewLeft
            camera = GetCamera("WorldCamera")
            InitReclaimGroup(view)
        end

        local labels = UpdateLabels()

        if ZoomHide then
            local zoom = camera:GetZoom()
            if zoom == OldZoom then
                ZoomHide = false
            else
                OldZoom = zoom
            end
        end

        if not ZoomHide then
            view.zoomed = false
            view.ReclaimGroup:Show()
            OldZoom = nil
        end

        WaitSeconds(.1)
    end

    if not IsDestroyed(view) then
        view.ReclaimThread = nil
        view.ReclaimGroup:Hide()
    end
end

function ToggleReclaim()
    local view = import('/lua/ui/game/worldview.lua').viewLeft
    ShowReclaim(not view.ShowingReclaim)
end

-- Called from commandgraph.lua:OnCommandGraphShow()
local CommandGraphActive = false
function OnCommandGraphShow(bool)
    local view = import('/lua/ui/game/worldview.lua').viewLeft
    if view.ShowingReclaim and not CommandGraphActive then return end -- if on by toggle key
    local options = Prefs.GetFromCurrentProfile('options')

    CommandGraphActive = bool
    if CommandGraphActive and options.gui_show_reclaim == 1 then
        ForkThread(function()
            local keydown
            while CommandGraphActive do
                keydown = IsKeyDown('Control')
                if keydown ~= view.ShowingReclaim then -- state has changed
                    ShowReclaim(keydown)
                end
                WaitSeconds(.1)
            end

            ShowReclaim(false)
        end)
    else
        CommandGraphActive = false -- above coroutine runs until now
    end
end
