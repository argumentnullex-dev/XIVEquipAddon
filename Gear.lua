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
end
