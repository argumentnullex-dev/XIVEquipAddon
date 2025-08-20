-- Gear.lua
local addonName, XIVEquip = ...
local L         = XIVEquip.L
local Comparers = XIVEquip.Comparers
local Hooks     = XIVEquip.Hooks

local Core = XIVEquip.Gear_Core

local C = {}
XIVEquip.Gear = C

local playerArmorSubclass = Core.playerArmorSubclass
local equipByBasics       = Core.equipByBasics

-- PlanBest returns (changes, pending, plan)
function C:PlanBest(cmp, opts)
  opts = opts or {}
  local used = {}
  local plan, changes = {}, {}
  local hadPending = false

  -- Require modules (no fallbacks)
  local aChanges, aPending, aPlan = XIVEquip.Armor:PlanBest(cmp, opts, used)
  local jChanges, jPending, jPlan = XIVEquip.Jewelry:PlanBest(cmp, opts, used)

  -- Merge armor + jewelry
  for _, r in ipairs(aChanges or {}) do table.insert(changes, r) end
  for _, r in ipairs(jChanges or {}) do table.insert(changes, r) end
  for _, p in ipairs(aPlan or {})    do table.insert(plan,    p) end
  for _, p in ipairs(jPlan or {})    do table.insert(plan,    p) end

  hadPending = (aPending == true) or (jPending == true)

  -- Weapons: append only their 'changes' (unchanged behavior)
  if XIVEquip.Weapons and XIVEquip.Weapons.PlanBest then
    local wPlan, wChanges, wPending = XIVEquip.Weapons:PlanBest(cmp)
    if type(wChanges) == "table" then
      for _, row in ipairs(wChanges) do table.insert(changes, row) end
    end
    hadPending = hadPending or wPending or false
  end

  hadPending = hadPending or (XIVEquip._needsItemRetry == true)
  return changes, hadPending, plan
end

-- EquipBest unchanged (no fallback/retry)
function C:EquipBest()
  if InCombatLockdown() then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.CannotCombat or "Cannot equip while in combat."))
    return
  end

  local cmp = Comparers:StartPass()
  local showEquip = (_G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip) ~= false
  local anyChange = false

  local _, _, plan = C:PlanBest(cmp)

  for _, pick in ipairs(plan) do
    local slotID  = pick.targetSlot
    local oldLink = (slotID and GetInventoryItemLink("player", slotID)) or "|cff888888(None)|r"
    local newLink = equipByBasics(pick) or oldLink
    if newLink ~= oldLink then
      anyChange = true
      if showEquip then
        print((L.AddonPrefix or "XIVEquip: ") .. string.format(L.ReplacedWith or "Replaced %s with %s.", oldLink, newLink))
      end
    end
  end

  if showEquip and not anyChange then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.NoUpgrades or "No upgrades found."))
  end

  Comparers:EndPass()
end
