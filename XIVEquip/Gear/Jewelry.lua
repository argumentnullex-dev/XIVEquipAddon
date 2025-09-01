-- Jewelry.lua
local addonName, XIVEquip = ...
local Core                = XIVEquip.Gear_Core

local J                   = {}
XIVEquip.Jewelry          = J

local playerArmorSubclass = Core.playerArmorSubclass
local tryChooseAppend     = Core.tryChooseAppend

-- PlanBest returns (changes, pending, plan); accepts shared `used` table
function J:PlanBest(cmp, opts, used)
  opts = opts or {}
  used = used or {}

  local expectedArmor = playerArmorSubclass()
  local plan, changes = {}, {}
  local hadPending = false

  -- Cloak, Neck, Ring1, Ring2, Trinket1, Trinket2
  for _, slotID in ipairs(Core.JEWELRY_SLOTS) do
    tryChooseAppend(plan, changes, slotID, cmp, expectedArmor, used)
  end

  hadPending = hadPending or (XIVEquip._needsItemRetry == true)
  return changes, hadPending, plan
end
