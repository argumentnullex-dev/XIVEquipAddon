-- Armor.lua
local addonName, XIVEquip = ...
local Core = XIVEquip.Gear_Core

local A = {}
XIVEquip.Armor = A

local playerArmorSubclass = Core.playerArmorSubclass
local tryChooseAppend     = Core.tryChooseAppend

-- PlanBest returns (changes, pending, plan); accepts shared `used` table
function A:PlanBest(cmp, opts, used)
  opts = opts or {}
  used = used or {}

  local expectedArmor = playerArmorSubclass()
  local plan, changes = {}, {}
  local hadPending = false

  -- Armor order (no weapons/cloak/jewelry here)
  for _, slotID in ipairs({ 1,3,5,6,7,8,9,10 }) do
    tryChooseAppend(plan, changes, slotID, cmp, expectedArmor, used)
  end

  hadPending = hadPending or (XIVEquip._needsItemRetry == true)
  return changes, hadPending, plan
end
