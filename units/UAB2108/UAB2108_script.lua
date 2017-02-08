-----------------------------------------------------------------
-- File     :  /cdimage/units/UAB2108/UAB2108_script.lua
-- Author(s):  John Comes, David Tomandl
-- Summary  :  Aeon Tactical Missile Launcher Script
-- Copyright � 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------

local AStructureUnit = import('/lua/aeonunits.lua').AStructureUnit
local ACruiseMissileWeapon = import('/lua/aeonweapons.lua').ACruiseMissileWeapon
local ManualLaunchWeapon = import('/lua/sim/defaultweapons.lua').ManualLaunchWeapon

UAB2108 = Class(AStructureUnit) {
    Weapons = {
        CruiseMissile = Class(ACruiseMissileWeapon, ManualLaunchWeapon) {},
    },
}

TypeClass = UAB2108
