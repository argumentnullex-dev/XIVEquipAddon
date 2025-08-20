-- Gear.lua
local addonName, XIVEquip = ...
local L         = XIVEquip.L
local Comparers = XIVEquip.Comparers
local Hooks     = XIVEquip.Hooks

local Core = XIVEquip.Gear_Core

local C = {}
XIVEquip.Gear = C

-- Keep local aliases for readability; logic is identical to the working file
local ARMOR_SLOTS        = Core.ARMOR_SLOTS
local JEWELRY            = Core.JEWELRY
local LOWER_ILVL_ARMOR   = Core.LOWER_ILVL_ARMOR
local LOWER_ILVL_JEWELRY = Core.LOWER_ILVL_JEWELRY
local SLOT_EQUIPLOCS     = Core.SLOT_EQUIPLOCS
local ITEMCLASS_ARMOR    = Core.ITEMCLASS_ARMOR
local SLOT_LABEL         = Core.SLOT_LABEL

local equippedBasics     = Core.equippedBasics
local equipByBasics      = Core.equipByBasics
local equipLocMatchesSlot= Core.equipLocMatchesSlot
local playerArmorSubclass= Core.playerArmorSubclass
local getItemLevelFromLink = Core.getItemLevelFromLink
local itemGUID           = Core.itemGUID

-- =========================
-- Public API
-- =========================

-- PlanBest now returns:
--   plan    : array of picks (armor/jewelry) in equip order
--   changes : the same array your UI uses today
--   pending : whether item loads were requested
function C:PlanBest(cmp, opts)
  opts = opts or {}
  local expectedArmor = playerArmorSubclass()
  local used = {}
  local plan = {}
  local changes = {}
  local hadPending = false

  local order = { 1,3,5,6,7,8,9,10,15,2,11,12,13,14 }

  for _, slotID in ipairs(order) do
    local pick, equipped = Core.chooseForSlot(cmp, slotID, expectedArmor, used)
    if pick then
      -- record in plan (so EquipBest can commit without re-search)
      table.insert(plan, pick)

      local oldLink   = (equipped and equipped.link) or "|cff888888(None)|r"
      local newLink   = pick.link or oldLink
      local newScore  = (pick and pick.score) or 0
      local oldScore  = (equipped and equipped.score) or 0
      local newIlvl   = (pick and pick.ilvl) or 0
      local oldIlvl   = (equipped and equipped.ilvl) or 0

      table.insert(changes, {
        slot        = slotID,
        slotName    = SLOT_LABEL[slotID] or ("Slot "..slotID),
        oldLink     = oldLink,
        newLink     = newLink,
        deltaScore  = newScore - oldScore,
        deltaIlvl   = newIlvl - oldIlvl,
        newLoc      = pick.loc,
        oldLoc      = equipped and equipped.loc or nil,
        scaleValues = pick.scaleValues,
      })

      if pick.guid then
        used[pick.guid] = true
      end
    end
  end

  -- Keep weapon behavior identical to working file:
  -- only append their "changes" for the UI, do NOT add to plan here.
  if XIVEquip.Weapons and XIVEquip.Weapons.PlanBest then
    local wPlan, wChanges, wPending = XIVEquip.Weapons:PlanBest(cmp)
    if type(wChanges) == "table" then
      for _, row in ipairs(wChanges) do
        table.insert(changes, row)
      end
    end
    hadPending = hadPending or wPending or false
  end

  hadPending = hadPending or (XIVEquip._needsItemRetry == true)

  -- IMPORTANT: UI expects (changes, pending); EquipBest will read plan as the 3rd return.
  return changes, hadPending, plan
end

-- EquipBest: commit the plan; delegates weapons; no fallback/retry here.
function C:EquipBest()
  if InCombatLockdown() then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.CannotCombat or "Cannot equip while in combat."))
    return
  end

  local cmp = Comparers:StartPass()
  local showEquip = (_G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip) ~= false
  local anyChange = false

  -- Note: plan is the THIRD return value for UI back-compat
  local _, _, plan = C:PlanBest(cmp)

  -- Equip armor/jewelry from the plan
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

  -- Weapons unchanged
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
