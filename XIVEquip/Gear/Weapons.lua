-- Weapons.lua
local addonName, XIVEquip = ...
local Core = XIVEquip.Gear_Core

local W = {}
XIVEquip.Weapons = W

-- Slots
local MH, OH = 16, 17

-- Equip location buckets (shape only)
local MH2H = {
  INVTYPE_2HWEAPON = true,
  INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
  INVTYPE_THROWN = true,
}
local MH1H = {
  INVTYPE_WEAPON = true,
  INVTYPE_WEAPONMAINHAND = true,
}

-- -------- Spec-aware policy --------

local function currentSpecID()
  local idx = GetSpecialization and GetSpecialization()
  if not idx then return nil end
  return (GetSpecializationInfo(idx))
end

-- Policy fields:
-- allow2H, allowDualWield, allowOffhandWeapon, allowShield, allowHoldable, allowMH1H, requireShield
local function policyForSpec()
  local class = select(2, UnitClass("player"))
  local spec  = currentSpecID()

  local P = {
    allow2H = true, allowDualWield = false, allowOffhandWeapon = false,
    allowShield = false, allowHoldable = false, allowMH1H = true, requireShield = false,
  }

  if class == "WARRIOR" then
    if spec == 71 then P.allow2H=true;  P.allowMH1H=false                                  -- Arms
    elseif spec == 72 then P.allow2H=true; P.allowDualWield=true; P.allowOffhandWeapon=true -- Fury
    elseif spec == 73 then P.allow2H=false; P.allowMH1H=true; P.allowShield=true; P.requireShield=true end -- Prot
  elseif class == "PALADIN" then
    if spec == 65 then -- Holy
      -- Holy can use 1H + Shield OR 1H + Holdable (frill). Do not force shields.
      P.allow2H       = false
      P.allowMH1H     = true
      P.allowShield   = true
      P.allowHoldable = true
      P.requireShield = false
    elseif spec == 66 then -- Protection
      P.allow2H       = false
      P.allowMH1H     = true
      P.allowShield   = true
      P.requireShield = true   -- Prot must have a shield
    elseif spec == 70 then -- Retribution
      P.allow2H       = true
      P.allowMH1H     = false -- you will never use just a 1H weapon as Ret
    end
  elseif class == "ROGUE" or class == "DEMONHUNTER" then
    P.allow2H=false; P.allowDualWield=true; P.allowOffhandWeapon=true
  elseif class == "DEATHKNIGHT" then
    if spec == 250 then P.allow2H=true;  P.allowMH1H=false                     -- Blood
    elseif spec == 251 then P.allow2H=true; P.allowDualWield=true; P.allowOffhandWeapon=true -- Frost
    elseif spec == 252 then P.allow2H=true;  P.allowMH1H=false end             -- Unholy
  elseif class == "SHAMAN" then
    if spec == 263 then P.allow2H=false; P.allowDualWield=true; P.allowOffhandWeapon=true -- Enhance
    else P.allow2H=true; P.allowMH1H=true; P.allowShield=true; P.allowHoldable=true end   -- Ele/Resto
  elseif class == "DRUID" then
    if spec == 103 or spec == 104 then P.allow2H=true; P.allowMH1H=false else  -- Feral/Guardian
      P.allow2H=true; P.allowMH1H=true; P.allowHoldable=true end               -- Balance/Resto
  elseif class == "HUNTER" then
    P.allow2H=true; P.allowMH1H=false
  elseif class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
    P.allow2H=true; P.allowMH1H=true; P.allowHoldable=true
  elseif class == "MONK" then
    if spec == 269 then P.allow2H=true; P.allowDualWield=true; P.allowOffhandWeapon=true   -- WW
    elseif spec == 268 then P.allow2H=true; P.allowMH1H=true                                -- Brew
    elseif spec == 270 then P.allow2H=true; P.allowMH1H=true; P.allowHoldable=true end      -- MW
  elseif class == "EVOKER" then
    P.allow2H=true; P.allowMH1H=true; P.allowHoldable=true
  end

  if IsDualWielding and IsDualWielding() then
    P.allowDualWield = true; P.allowOffhandWeapon = true
  end

  return P
end

local function offhandLocAllowed(equipLoc, P)
  if equipLoc == "INVTYPE_SHIELD"      then return P.allowShield end
  if equipLoc == "INVTYPE_HOLDABLE"    then return P.allowHoldable end
  if equipLoc == "INVTYPE_WEAPONOFFHAND" then return P.allowOffhandWeapon end
  if equipLoc == "INVTYPE_WEAPON"      then return P.allowDualWield end
  return false
end

local function is2H(equipLoc) return equipLoc and MH2H[equipLoc] end
local function is1H(equipLoc) return equipLoc and MH1H[equipLoc] end

-- Is the *currently equipped* combo valid for this spec policy?
local function currentComboValid(P, eqMH, eqOH)
  if not (eqMH and eqMH.equipLoc) then return false end
  if is2H(eqMH.equipLoc) then
    if not P.allow2H then return false end
    if eqOH and eqOH.equipLoc then return false end -- 2H can't have OH
    return true
  else
    if not (P.allowMH1H and is1H(eqMH.equipLoc)) then return false end
    if eqOH and eqOH.equipLoc then
      if not offhandLocAllowed(eqOH.equipLoc, P) then return false end
      if P.requireShield and eqOH.equipLoc ~= "INVTYPE_SHIELD" then return false end
      return true
    else
      if P.requireShield then return false end
      return true
    end
  end
end

-- -------- scoring/picks --------

local function makePick(itemLoc, link, equipLoc, slotID, score)
  return {
    loc        = itemLoc,
    guid       = Core.itemGUID(itemLoc),
    link       = link,
    score      = score or 0,
    ilvl       = Core.getItemLevelFromLink(link),
    equipLoc   = equipLoc,
    targetSlot = slotID,
  }
end

local function collectCandidates(cmp, used, P)
  local mh2h, mh1h, oh = {}, {}, {}
  for bag = 0, NUM_BAG_SLOTS do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local _, _, _, equipLoc = GetItemInfoInstant(info.itemID)
        if equipLoc then
          local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
          local loc  = ItemLocation:CreateFromBagAndSlot(bag, slot)
          local guid = Core.itemGUID(loc)
          if not (used and guid and used[guid]) then
            if MH2H[equipLoc] and P.allow2H then
              table.insert(mh2h, { loc=loc, link=link, equipLoc=equipLoc, scoreMH=Core.scoreItem(cmp, loc, MH) })
            elseif MH1H[equipLoc] and P.allowMH1H then
              table.insert(mh1h, { loc=loc, link=link, equipLoc=equipLoc, scoreMH=Core.scoreItem(cmp, loc, MH) })
            end
            if offhandLocAllowed(equipLoc, P) then
              table.insert(oh, { loc=loc, link=link, equipLoc=equipLoc, scoreOH=Core.scoreItem(cmp, loc, OH) })
            end
          end
        end
      end
    end
  end
  return mh2h, mh1h, oh
end

local function bestOH(ohList, excludeGuid)
  local best, bestScore = nil, -math.huge
  for _, o in ipairs(ohList) do
    local guid = Core.itemGUID(o.loc)
    if (not excludeGuid) or (guid ~= excludeGuid) then
      local s = o.scoreOH or 0
      if s > bestScore then best, bestScore = o, s end
    end
  end
  return best, bestScore
end

-- -------- public --------

-- PlanBest returns (changes, pending, plan)
function W:PlanBest(cmp, opts, used)
  opts = opts or {}
  used = used or {}

  local plan, changes = {}, {}
  local hadPending = false
  local EPS = 1e-6

  local P = policyForSpec()

  -- Equipped baseline (but invalidate if combo is illegal)
  local eqMH = Core.equippedBasics(MH, cmp)
  local eqOH = Core.equippedBasics(OH, cmp)
  local base
  if currentComboValid(P, eqMH, eqOH) then
    base = (eqMH and eqMH.score or 0) + (eqOH and eqOH.score or 0)
  else
    base = -math.huge -- force a valid swap even if their current gear scores high
  end

  -- Collect & score candidates with policy filtering
  local mh2h, mh1h, oh = collectCandidates(cmp, used, P)

  -- Evaluate options
  local best = nil
  local function better(curr, s) return (not curr) or (s > curr.score) end

  -- A) 2H main-hand
  if P.allow2H then
    for _, w in ipairs(mh2h) do
      local S = w.scoreMH or 0
      if better(best, S) then best = { kind="2H", score=S, mh=w } end
    end
  end

  -- B) 1H MH + best OH from bag (OH already policy-filtered; shield enforced if required)
  if next(oh) ~= nil then
    for _, m in ipairs(mh1h) do
      local guidMH = Core.itemGUID(m.loc)
      local o, so = bestOH(oh, guidMH)
      if o then
        if (not P.requireShield) or (o.equipLoc == "INVTYPE_SHIELD") then
          local S = (m.scoreMH or 0) + (so or 0)
          if better(best, S) then best = { kind="PAIR_BAG", score=S, mh=m, oh=o } end
        end
      end
    end
  end

  -- C) 1H MH + keep current OH (only if current OH complies with policy)
  if eqOH and eqOH.score and offhandLocAllowed(eqOH.equipLoc, P) then
    if (not P.requireShield) or (eqOH.equipLoc == "INVTYPE_SHIELD") then
      for _, m in ipairs(mh1h) do
        local S = (m.scoreMH or 0) + (eqOH.score or 0)
        if better(best, S) then best = { kind="PAIR_KEEP", score=S, mh=m } end
      end
    end
  end

  -- D) Keep current MH + OH upgrade (only if MH isn't 2H, and OH permitted)
  local mhIs2H = eqMH and eqMH.equipLoc and MH2H[eqMH.equipLoc]
  if not mhIs2H and next(oh) ~= nil then
    local o, so = bestOH(oh, nil)
    if o then
      if (not P.requireShield) or (o.equipLoc == "INVTYPE_SHIELD") then
        local S = (eqMH and eqMH.score or 0) + (so or 0)
        if better(best, S) then best = { kind="OH_ONLY", score=S, oh=o } end
      end
    end
  end

  -- Upgrade guard
  if not best or (best.score <= base + EPS) then
    hadPending = hadPending or (XIVEquip._needsItemRetry == true)
    return changes, hadPending, plan
  end

  -- Build plan/changes (equip order matters) + mark 'used'
  if best.kind == "2H" then
    local pMH = makePick(best.mh.loc, best.mh.link, best.mh.equipLoc, MH, best.mh.scoreMH)
    Core.appendPlanAndChange(plan, changes, MH, pMH, eqMH)
    if pMH.guid then used[pMH.guid] = true end
  elseif best.kind == "PAIR_BAG" then
    local pMH = makePick(best.mh.loc, best.mh.link, best.mh.equipLoc, MH, best.mh.scoreMH)
    Core.appendPlanAndChange(plan, changes, MH, pMH, eqMH); if pMH.guid then used[pMH.guid] = true end
    local pOH = makePick(best.oh.loc, best.oh.link, best.oh.equipLoc, OH, best.oh.scoreOH)
    Core.appendPlanAndChange(plan, changes, OH, pOH, eqOH); if pOH.guid then used[pOH.guid] = true end
  elseif best.kind == "PAIR_KEEP" then
    local pMH = makePick(best.mh.loc, best.mh.link, best.mh.equipLoc, MH, best.mh.scoreMH)
    Core.appendPlanAndChange(plan, changes, MH, pMH, eqMH); if pMH.guid then used[pMH.guid] = true end
  elseif best.kind == "OH_ONLY" then
    local pOH = makePick(best.oh.loc, best.oh.link, best.oh.equipLoc, OH, best.oh.scoreOH)
    Core.appendPlanAndChange(plan, changes, OH, pOH, eqOH); if pOH.guid then used[pOH.guid] = true end
  end

  hadPending = hadPending or (XIVEquip._needsItemRetry == true)
  return changes, hadPending, plan
end
