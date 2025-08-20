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
  local expectedArmor = playerArmorSubclass()
  local used, plan, changes = {}, {}, {}
  local hadPending = false

  -- Armor only (cloak/jewelry handled in Jewelry.lua)
  for _, slotID in ipairs({ 1,3,5,6,7,8,9,10 }) do
    Core.tryChooseAppend(plan, changes, slotID, cmp, expectedArmor, used)
  end

  -- Jewelry module (merged into plan/changes)
  local jChanges, jPending, jPlan
  if XIVEquip.Jewelry and XIVEquip.Jewelry.PlanBest then
    jChanges, jPending, jPlan = XIVEquip.Jewelry:PlanBest(cmp, opts, used)
  else
    -- Fallback if Jewelry.lua isn't loaded yet (keeps behavior identical)
    jPlan, jChanges = {}, {}
    for _, slotID in ipairs({15,2,11,12,13,14}) do
      Core.tryChooseAppend(jPlan, jChanges, slotID, cmp, expectedArmor, used)
    end
    jPending = (XIVEquip._needsItemRetry == true)
  end

  for _, r in ipairs(jChanges or {}) do table.insert(changes, r) end
  for _, p in ipairs(jPlan or {})    do table.insert(plan,    p) end
  hadPending = hadPending or (jPending == true)

  -- Weapons: append only their 'changes' (unchanged)
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

  if XIVEquip.Weapons and XIVEquip.Weapons.PlanBest and XIVEquip.Weapons.EquipBest then
    local weaponPlan = select(1, XIVEquip.Weapons:PlanBest(cmp))
    local changed = XIVEquip.Weapons:EquipBest(cmp, weaponPlan, showEquip)
    anyChange = anyChange or changed
  end

  if showEquip and not anyChange then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.NoUpgrades or "No upgrades found."))
  end

  Comparers:EndPass()
end
