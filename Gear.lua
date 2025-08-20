-- Gear.lua
local addonName, XIVEquip = ...
local L         = XIVEquip.L
local Comparers = XIVEquip.Comparers
local Hooks     = XIVEquip.Hooks

local C = {}
XIVEquip.Gear = C

-- Inventory slots handled here (weapons are handled in Weapons.lua)
local ARMOR_SLOTS = { 1,2,3,5,6,7,8,9,10,15, 11,12, 13,14 } -- head..cloak, rings x2, trinkets x2
local JEWELRY     = { [2]=true, [15]=true, [11]=true, [12]=true, [13]=true, [14]=true }

local LOWER_ILVL_ARMOR   = 20
local LOWER_ILVL_JEWELRY = 40

local INV_BY_EQUIPLOC = {
  INVTYPE_HEAD=1, INVTYPE_NECK=2, INVTYPE_SHOULDER=3, INVTYPE_BODY=4, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
  INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10,
  INVTYPE_FINGER=11, INVTYPE_TRINKET=13, INVTYPE_CLOAK=15, INVTYPE_HOLDABLE=17, INVTYPE_SHIELD=17,
}

local SLOT_EQUIPLOCS = {
  [1]  = { INVTYPE_HEAD=true },   [2]  = { INVTYPE_NECK=true },   [3]  = { INVTYPE_SHOULDER=true },
  [5]  = { INVTYPE_CHEST=true, INVTYPE_ROBE=true },              [6]  = { INVTYPE_WAIST=true },
  [7]  = { INVTYPE_LEGS=true },   [8]  = { INVTYPE_FEET=true },   [9]  = { INVTYPE_WRIST=true },
  [10] = { INVTYPE_HAND=true },   [15] = { INVTYPE_CLOAK=true },
  [11] = { INVTYPE_FINGER=true }, [12] = { INVTYPE_FINGER=true },
  [13] = { INVTYPE_TRINKET=true },[14] = { INVTYPE_TRINKET=true },
}

local ITEMCLASS_ARMOR = 4

-- Stable key for a physical item instance
local function ItemInstanceKey(itemLoc)
  if C_Item and C_Item.GetItemGUID and itemLoc then
    local ok, guid = pcall(C_Item.GetItemGUID, itemLoc)
    if ok and guid and guid ~= "" then return guid end
  end
  -- fallback: itemID + bag/slot
  local link = C_Item and C_Item.GetItemLink and C_Item.GetItemLink(itemLoc)
  local id = link and tonumber(link:match("|Hitem:(%d+)"))
  local bag, slot = itemLoc and itemLoc.bagID, itemLoc and itemLoc.slotIndex
  return table.concat({id or 0, bag or -1, slot or -1}, ":")
end

local function itemGUID(loc)
  if C_Item and C_Item.GetItemGUID and loc then
    local ok, guid = pcall(C_Item.GetItemGUID, loc)
    if ok then return guid end
  end
  return nil
end

local function getItemLevelFromLink(link)
  if not link then return 0 end
  local il = select(4, GetItemInfo(link))
  if il and il > 0 then return il end
  local _, _, _, iLvl = GetItemInfoInstant(link)
  return iLvl or 0
end

-- Read currently equipped for a slot
local function equippedBasics(slotID, comparer)
  local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
  if not (loc and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then return nil end

  local link = GetInventoryItemLink("player", slotID)
  if not link and C_Item.GetItemLink then link = C_Item.GetItemLink(loc) end

  local ilvl = 0
  if C_Item.GetCurrentItemLevel then ilvl = C_Item.GetCurrentItemLevel(loc) or 0 end
  if ilvl == 0 then ilvl = getItemLevelFromLink(link) end

  local equipLoc = link and select(9, GetItemInfo(link)) or nil

  local score = nil
  if comparer and comparer.ScoreItem then
    local ok, v = pcall(comparer.ScoreItem, loc, slotID)
    if ok and type(v)=="number" then score = v end
  end

  return { loc=loc, slot=slotID, link=link, ilvl=ilvl, score=score, equipLoc=equipLoc }
end

-- Equip a bag item into a specific slot, return link (fallback to bag link if inventory not updated yet)
local function equipByBasics(pick)
  if not pick then return nil end

  -- FIX: accept either pick.loc or pick.itemLoc and DON'T return early if it's a bag loc
  local loc = pick.loc or pick.itemLoc
  local bag, slot = nil, nil

  if loc and loc.GetEquipmentSlot then
    local inv = loc:GetEquipmentSlot()
    if inv then
      -- already an equipment location; nothing to equip
      return GetInventoryItemLink("player", inv) or pick.link
    end
    if loc.GetBagAndSlot then
      bag, slot = loc:GetBagAndSlot()
    end
  end

  if not bag then
    bag, slot = pick.bagID, pick.slotIndex
  end
  if not bag or not slot then
    -- we at least return the link so the caller prints something sensible
    return pick.link
  end

  -- FIX: force exact inventory slot (ring2/trinket2 etc.)
  local invSlot = pick.targetSlot or (pick.equipLoc and INV_BY_EQUIPLOC[pick.equipLoc]) or nil

  ClearCursor()
  C_Container.PickupContainerItem(bag, slot)
  if invSlot then
    EquipCursorItem(invSlot)
  else
    EquipCursorItem()
  end
  ClearCursor()

  return (invSlot and GetInventoryItemLink("player", invSlot)) or pick.link
end

local function equipLocMatchesSlot(equipLoc, slotID)
  local allowed = SLOT_EQUIPLOCS[slotID]
  return allowed and allowed[equipLoc] or false
end

local function playerArmorSubclass()
  local class = select(2, UnitClass("player"))
  local map = {
    WARRIOR=4, PALADIN=4, DEATHKNIGHT=4,
    HUNTER=3, SHAMAN=3, EVOKER=3,
    ROGUE=2, MONK=2, DEMONHUNTER=2, DRUID=2,
    MAGE=1, PRIEST=1, WARLOCK=1,
  }
  return map[class]
end

-- Choose best item for one slot; only return if it's an upgrade over equipped.
local EPS = 1e-6
function chooseForSlot(comparer, slotID, expectedArmorSubclass, used)
  local equipped = equippedBasics(slotID, comparer)
  local equippedIlvl   = (equipped and equipped.ilvl) or 0
  local equippedScore  = (equipped and equipped.score) or nil
  local lowerBound     = JEWELRY[slotID] and LOWER_ILVL_JEWELRY or LOWER_ILVL_ARMOR

  local best = nil

  for bag = 0, NUM_BAG_SLOTS do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(info.itemID)
        if equipLoc and equipLocMatchesSlot(equipLoc, slotID) then
          local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
          local ilvl = getItemLevelFromLink(link)
          if ilvl >= (equippedIlvl - lowerBound) then
            local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            local guid = itemGUID(itemLoc)
            if not (used and guid and used[guid]) then
              local score = nil
              if comparer and comparer.ScoreItem then
                local ok, v = pcall(comparer.ScoreItem, itemLoc, slotID)
                if ok and type(v) == "number" then score = v end
              end
              if score and (not best or score > best.score) then
                best = {
                  loc        = itemLoc,
                  guid       = guid,
                  link       = link,
                  score      = score,
                  ilvl       = ilvl,
                  equipLoc   = equipLoc,
                  targetSlot = slotID,
                }
              end
            end
          end
        end
      end
    end
  end

  -- Guard: only upgrade if strictly better than what’s on the character.
  if best then
    if equippedScore ~= nil then
      if best.score <= (equippedScore + EPS) then
        -- not an upgrade by Pawn score
        return nil, equipped
      end
    else
      -- Equipped piece isn’t scoreable; don’t downgrade ilvl.
      if best.ilvl <= equippedIlvl then
        return nil, equipped
      end
    end
  end

  return best, equipped
end

-- Pretty slot labels for the tooltip
local SLOT_LABEL = {
  [1]="Head", [2]="Neck", [3]="Shoulder", [5]="Chest", [6]="Waist",
  [7]="Legs", [8]="Feet", [9]="Wrist", [10]="Hands", [11]="Ring 1",
  [12]="Ring 2", [13]="Trinket 1", [14]="Trinket 2", [15]="Back",
}

-- Plan changes without equipping. Returns { {slot,slotName,oldLink,newLink,deltaScore,deltaIlvl}, ... }, hadPendingLoad
function C:PlanBest(cmp, opts)
  opts = opts  or {}
  local expectedArmor = playerArmorSubclass()
  local used = {}
  local changes = {}
  local hadPending = false
  -- same pass order you equip with
  local order = { 1,3,5,6,7,8,9,10,15,2,11,12,13,14 }

  for _, slotID in ipairs(order) do
    local pick, equipped = chooseForSlot(cmp, slotID, expectedArmor, used)
    if pick then
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

      -- Mark the selected item as used by adding its GUID to the used table
      if pick.guid then
        used[pick.guid] = true
      end
    end
  end

  -- Merge WEAPONS in the same plan so preview & equip paths “just work”.
  if XIVEquip.Weapons and XIVEquip.Weapons.PlanBest then
    local wPlan, wChanges, wPending = XIVEquip.Weapons:PlanBest(cmp)
    if type(wChanges) == "table" then
      for _, row in ipairs(wChanges) do
        table.insert(changes, row)
      end
    end
    hadPending = hadPending or wPending or false
  end

  -- if ScoreItem asked for item loads during plan, surface that so the UI can hint “loading…”
  hadPending = hadPending or (XIVEquip._needsItemRetry == true)

  return changes, hadPending
end

local lastRetryAt = 0

function C:EquipBest()
  if InCombatLockdown() then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.CannotCombat or "Cannot equip while in combat."))
    return
  end

  XIVEquip._needsItemRetry = false
  local cmp = Comparers:StartPass()
  local expectedArmor = playerArmorSubclass()
  local showEquip = (_G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip) ~= false
  local anyChange = false
  local used = {}

  -- helper to equip and mark used
  local function equipPick(slotID, pick, equipped)
    if not pick then return false end
    -- TODO: the oldLink doesn't seem to be working quite right here, the Replaced message doesn't print if the oldLink was an item instead of None
    local oldLink = (equipped and equipped.link) or "|cff888888(None)|r"
    local newLink = equipByBasics(pick) or oldLink
    if pick.guid then used[pick.guid] = true end
    if newLink ~= oldLink then
      if showEquip then
        print((L.AddonPrefix or "XIVEquip: ") .. string.format(L.ReplacedWith or "Replaced %s with %s.", oldLink, newLink))
      end
      return true
    end
    return false
  end

  -- Armor + jewelry
  local order = { 1,3,5,6,7,8,9,10,15,2,11,12,13,14 }  -- head, shoulder,... cloak, neck, ring1, ring2, trinket1, trinket2
  for _, slotID in ipairs(order) do
    local pick, equipped = chooseForSlot(cmp, slotID, expectedArmor, used)
    if equipPick(slotID, pick, equipped) then anyChange = true end
  end

  -- Weapons: use the weapons module's plan + equip
  if XIVEquip.Weapons and XIVEquip.Weapons.PlanBest and XIVEquip.Weapons.EquipBest then
    local weaponPlan = select(1, XIVEquip.Weapons:PlanBest(cmp))  -- plan (we ignore the changes here)
    local changed = XIVEquip.Weapons:EquipBest(cmp, weaponPlan, showEquip)
    anyChange = anyChange or changed
  end

  if showEquip and not anyChange then
    print((L.AddonPrefix or "XIVEquip: ") .. (L.NoUpgrades or "No upgrades found."))
  end

  Comparers:EndPass()

  -- One light retry if we had to load item data this pass
  if not anyChange and XIVEquip._needsItemRetry and not InCombatLockdown() then
    XIVEquip._needsItemRetry = false
    local now = GetTime and GetTime() or 0
    if (now - lastRetryAt) > 0.5 then
      lastRetryAt = now
      C_Timer.After(0.25, function()
        if not InCombatLockdown() then
          -- run a silent pass (don’t spam messages)
          local prev = _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Equip
          if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages then
            _G.XIVEquip_Settings.Messages.Equip = false
          end
          C:EquipBest()
          if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages then
            _G.XIVEquip_Settings.Messages.Equip = prev
          end
        end
      end)
    end
  end
end
