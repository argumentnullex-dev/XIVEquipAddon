-- Gear.lua
local addonName, XIVEquip = ...
local L         = XIVEquip.L
local Comparers = XIVEquip.Comparers
local Hooks     = XIVEquip.Hooks

local Core = XIVEquip.Gear_Core

local C = {}
XIVEquip.Gear = C

local equipByBasics = Core.equipByBasics

-- =========================
-- Public API
-- =========================

-- PlanBest returns (changes, pending, plan)
function C:PlanBest(cmp, opts)
  opts = opts or {}

  local used = {}
  local plan, changes = {}, {}
  local hadPending = false

  -- Orchestrate planners in this order
  local planners = {
    XIVEquip.Armor,
    XIVEquip.Jewelry,
    XIVEquip.Weapons,
  }

  for _, planner in ipairs(planners) do
    -- No fallbacks: assume modules are loaded and expose PlanBest
    local pChanges, pPending, pPlan = planner:PlanBest(cmp, opts, used)

    for _, r in ipairs(pChanges or {}) do table.insert(changes, r) end
    for _, p in ipairs(pPlan or {})    do table.insert(plan,    p) end
    hadPending = hadPending or (pPending == true)
  end

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

  C:SaveEquippedToSpecSet()
end

-- =========================
-- Equipment Set helper
-- =========================
-- Saves the *currently equipped* items to a gear set named "<Spec>.xive".
-- If the set doesn't exist yet, it is created (using the spec icon if available), then saved.
function C:SaveEquippedToSpecSet()
  -- Be graceful if the API isn't available or we're in combat
  if type(C_EquipmentSet) ~= "table" or InCombatLockdown and InCombatLockdown() then return end

  local specIndex = GetSpecialization and GetSpecialization()
  local specName, specIcon = "Spec", nil
  if specIndex then
    local _, sName, _, sIcon = GetSpecializationInfo(specIndex)
    if sName and sName ~= "" then specName = sName end
    specIcon = sIcon
  end

  local setName = (specName or "Spec") .. ".xive"

  -- Find or create the set
  local setID = C_EquipmentSet.GetEquipmentSetID and C_EquipmentSet.GetEquipmentSetID(setName)
  if not setID then
    local icon = specIcon or 134400 -- fallback generic icon
    if C_EquipmentSet.CreateEquipmentSet then
      pcall(C_EquipmentSet.CreateEquipmentSet, setName, icon)
      -- re-fetch id after create
      setID = C_EquipmentSet.GetEquipmentSetID and C_EquipmentSet.GetEquipmentSetID(setName) or setID
    end
  else
    -- Optional: update icon to spec icon if available
    if specIcon and C_EquipmentSet.ModifyEquipmentSetIcon then
      pcall(C_EquipmentSet.ModifyEquipmentSetIcon, setID, specIcon)
    end
  end

  -- Save current equipment into the set
  if setID and C_EquipmentSet.SaveEquipmentSet then
    pcall(C_EquipmentSet.SaveEquipmentSet, setID)
    -- Optional message (quiet by default). Uncomment if you want confirmation:
    -- print((L.AddonPrefix or "XIVEquip: ") .. "Saved equipment set: " .. setName)
  end
end
