-- Gear.lua
local addonName, XIVEquip = ...
local L                   = XIVEquip.L
local Comparers           = XIVEquip.Comparers
local Hooks               = XIVEquip.Hooks

local Core                = XIVEquip.Gear_Core

local C                   = {}
XIVEquip.Gear             = C

local equipByBasics       = Core.equipByBasics

-- Upvalue to coalesce multiple save requests
local _pendingSpecSaveToken


-- =========================
-- Public API
-- =========================

-- Save the current equipment into a "Spec.xive" set *after* spec has stabilized.
-- Delay defaults to ~0.7s; bumped if needed.
-- [XIVEquip-AUTO] C:_saveSpecSetSoon: Helper for Gear module.
function C:_saveSpecSetSoon(delay)
  delay = delay or 0.7
  local token = {}
  _pendingSpecSaveToken = token

  -- Callback used in Interface.lua to run inline logic.
  C_Timer.After(delay, function()
    -- If a newer request came in, skip this one
    if _pendingSpecSaveToken ~= token then return end
    if InCombatLockdown() then return end

    -- Re-read the *current* spec now (don't use any captured value)
    local idx      = GetSpecialization()
    local specName = (idx and select(2, GetSpecializationInfo(idx))) or "Unknown"
    local setName  = string.format("%s.xive", specName)

    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetID then
      print((L.AddonPrefix or "XIVEquip: ") ..
        (L.SpecAuto_NoEM or "Cannot save equipment set: Equipment Manager API not available."))
      return
    end

    -- Ensure the set exists
    local setID = C_EquipmentSet.GetEquipmentSetID(setName)
    if not setID then
      -- Use the paperdoll icon as a harmless default if you don't have a favorite
      local icon = 134400
      C_EquipmentSet.CreateEquipmentSet(setName, icon)
      setID = C_EquipmentSet.GetEquipmentSetID(setName)
    end

    -- Save the currently equipped items
    if setID then
      C_EquipmentSet.SaveEquipmentSet(setID)
      if not (_G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip == false) then
        print((L.AddonPrefix or "XIVEquip: ") .. string.format(L.SpecAuto_Saved or "Saved equipment set '%s'.", setName))
      end
    end
  end)
end

-- PlanBest returns (changes, pending, plan)
-- [XIVEquip-AUTO] C:PlanBest: Helper for Gear module.
function C:PlanBest(cmp, opts)
  opts = opts or {}

  -- Reset per-pass socket potential messages
  if Core and type(Core.ClearSocketPotential) == "function" then
    Core.ClearSocketPotential()
  end

  if Core and type(Core.ClearBoEReminders) == "function" then
    Core.ClearBoEReminders()
  end

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
    for _, p in ipairs(pPlan or {}) do table.insert(plan, p) end
    hadPending = hadPending or (pPending == true)
  end

  -- Capture socket potential records for UI / equip messages
  C._socketPotential = (Core and type(Core.GetSocketPotential) == "function") and (Core.GetSocketPotential() or {}) or {}
  C._boeReminders = (Core and type(Core.GetBoEReminders) == "function") and (Core.GetBoEReminders() or {}) or {}


  return changes, hadPending, plan
end

-- Public: get socket potential records from the last planning pass
function C:GetSocketPotential()
  return C._socketPotential or {}
end

function C:GetBoEReminders()
  return C._boeReminders or {}
end

-- EquipBest unchanged (no fallback/retry)
-- [XIVEquip-AUTO] C:EquipBest: Applies equipment changes (gear/weapons) for the addon.
function C:EquipBest()
  if InCombatLockdown() then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.CannotCombat or "Cannot equip while in combat."))
    return
  end

  local cmp = Comparers:StartPass()
  local showEquip = (_G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip) ~=
      false
  local anyChange = false
  local pendingChecks = 0

  local _, _, plan = C:PlanBest(cmp)

  -- Always surface "empty socket could be an upgrade" hints (not debug).
  do
    local recs = C:GetSocketPotential() or {}
    if #recs > 0 then
      for _, r in ipairs(recs) do
        local assumed = string.format("+%d %s", tonumber(r.assumedAmount) or 10,
          tostring(r.assumedStat or "best secondary"))
        local sockTxt = (tonumber(r.emptySockets) or 1) == 1 and "an empty socket" or
            (tostring(r.emptySockets) .. " empty sockets")
        local delta = tonumber(r.potentialDeltaScore) or 0
        print((L.AddonPrefix or "XIVEquip: ") .. string.format(
          "%s has %s and could potentially be an upgrade if gemmed (assumes %s): potential %+0.1f score improvement over alternative items.",
          tostring(r.link or "(item)"), sockTxt, assumed, delta))
      end
    end
  end

  if not plan or #plan == 0 then
    if showEquip then
      print((L.AddonPrefix or "XIVEquip: ") .. (L.NoUpgrades or "No upgrades found."))
    end
    Comparers:EndPass()
    return
  end

  local i = 1
  local function step()
    if i > #plan then
      local function finish()
        if pendingChecks > 0 then
          C_Timer.After(0.05, finish)
          return
        end

        if showEquip and not anyChange then
          print((L.AddonPrefix or "XIVEquip: ") .. (L.NoUpgrades or "No upgrades found."))
        end

        Comparers:EndPass()

        if not InCombatLockdown() then
          C:_saveSpecSetSoon(0.7)
        end
      end

      C_Timer.After(0.06, finish)
      return
    end

    if InCombatLockdown() then
      print((L.AddonPrefix or "XIVEquip: ") .. (L.CannotCombat or "Cannot equip while in combat."))
      Comparers:EndPass()
      return
    end

    local pick = plan[i] or {}
    -- try to identify pick item link from common shapes
    local pickLink =
        pick.newLink
        or (pick.bag and pick.slot and GetContainerItemLink and GetContainerItemLink(pick.bag, pick.slot))
        or (pick.fromSlot and GetInventoryItemLink("player", pick.fromSlot))
        or pick.link
        or ""

    local slotID = pick.targetSlot
        or (pick.equipLoc and Core.INV_BY_EQUIPLOC and Core.INV_BY_EQUIPLOC[pick.equipLoc])

    if pickLink and pickLink ~= "" and GetItemInfo then
      local name, _, _, ilvl, reqLevel, _, _, _, equipLoc = GetItemInfo(pickLink)
    end

    if slotID and IsInventoryItemLocked and IsInventoryItemLocked(slotID) then
      C_Timer.After(0.05, step)
      return
    end

    local oldLinkRaw = slotID and GetInventoryItemLink("player", slotID) or nil
    -- perform equip
    -- If this is an unbound BoE item, attempting to equip will usually raise a bind confirmation popup.
    -- We cannot click the confirmation for the player. If the equip doesn't take, emit a message and continue.
    local wasBoEUnbound = false
    do
      local bindType = pickLink and pickLink ~= "" and select(14, GetItemInfo(pickLink)) or nil
      if bindType == 2 then -- LE_ITEM_BIND_ON_EQUIP
        local bound = false
        if pick.loc and C_Item and type(C_Item.IsBound) == "function" then
          local okB, vB = pcall(C_Item.IsBound, pick.loc)
          bound = okB and vB or false
        end
        wasBoEUnbound = not bound
      end
    end

    local ok, err = pcall(function() equipByBasics(pick) end)

    if wasBoEUnbound then
      -- Check whether the intended item is actually equipped; if not, we're likely waiting on the bind popup.
      local nowLink = slotID and GetInventoryItemLink("player", slotID) or nil
      local function itemID(link)
        if type(link) ~= "string" then return nil end
        return tonumber(link:match("item:(%d+)"))
      end
      if itemID(nowLink) ~= itemID(pickLink) then
        -- IMPORTANT: Do not interrupt the routine. Continue equipping other upgrades.
        -- Surface a clear message so the user can equip manually.
        print((L.AddonPrefix or "XIVEquip: ") .. string.format(
          "%s is Bind on Equip and must be equipped manually.",
          tostring(pickLink or "(item)")))
        if ClearCursor then ClearCursor() end
      end
    end

    pendingChecks = pendingChecks + 1
    local pendingId = i -- correlate verify to pick index

    local function verifyEquip(slotID0, oldLink0, pickIndex)
      -- If slot is still locked, retry shortly
      if slotID0 and IsInventoryItemLocked and IsInventoryItemLocked(slotID0) then
        C_Timer.After(0.05, function()
          verifyEquip(slotID0, oldLink0, pickIndex)
        end)
        return
      end

      local newLink0 = slotID0 and GetInventoryItemLink("player", slotID0) or nil

      if newLink0 ~= oldLink0 then
        anyChange = true
        if showEquip then
          local oldText = oldLink0 or "|cff888888(None)|r"
          local newText = newLink0 or "|cff888888(None)|r"
          print((L.AddonPrefix or "XIVEquip: ") ..
            string.format(L.ReplacedWith or "Replaced %s with %s.", oldText, newText))
        end
      end

      pendingChecks = pendingChecks - 1
    end

    C_Timer.After(0.10, function()
      verifyEquip(slotID, oldLinkRaw, pendingId)
    end)

    i = i + 1
    C_Timer.After(0.05, step)
  end

  step()
end

-- =========================
-- Equipment Set helper
-- =========================
-- Saves the *currently equipped* items to a gear set named "<Spec>.xive".
-- If the set doesn't exist yet, it is created (using the spec icon if available), then saved.
-- [XIVEquip-AUTO] C:SaveEquippedToSpecSet: Helper for Gear module.
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
