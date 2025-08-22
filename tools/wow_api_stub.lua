-- tools/wow_api_stub.lua
-- Minimal WoW API stubs for editor/linters (no runtime effect in the game client)
-- Expand this file with additional APIs your addon uses.

---@class Frame
---@field RegisterEvent fun(self: Frame, event: string)
---@field RegisterAllEvents fun(self: Frame)
---@field UnregisterEvent fun(self: Frame, event: string)
---@field SetScript fun(self: Frame, script: string, handler: fun(self: Frame, event: string, ...: any))
---@field HookScript fun(self: Frame, script: string, handler: fun(self: Frame, ...: any))
---@field GetPoint fun(self: Frame, index: number) --> (point, rel, relPoint, x, y)
---@field ClearAllPoints fun(self: Frame)
---@field GetParent fun(self: Frame) : Frame
---@field GetFrameLevel fun(self: Frame) : number
---@field GetName fun(self: Frame) : string
---@field IsShown fun(self: Frame) : boolean
---@field SetPoint fun(self: Frame, point: string, rel: Frame, relPoint: string, x: number, y: number)
---@field SetParent fun(self: Frame, parent: Frame)
---@field GetName fun(self: Frame) : string
---@field SetSize fun(self: Frame, w: number, h: number)
---@field SetFrameStrata fun(self: Frame, strata: string)
---@field SetFrameLevel fun(self: Frame, level: number)
---@field SetClampedToScreen fun(self: Frame, flag: boolean)
---@field SetMovable fun(self: Frame, flag: boolean)
---@field RegisterForDrag fun(self: Frame, ...)
---@field StartMoving fun(self: Frame)
---@field StopMovingOrSizing fun(self: Frame)
---@field SetBackdrop fun(self: Frame, table)
---@field SetBackdropColor fun(self: Frame, r, g, b, a)
---@field SetBackdropBorderColor fun(self: Frame, r, g, b, a)
---@field SetNormalTexture fun(self: Frame, t)
---@field SetPushedTexture fun(self: Frame, t)
---@field SetDisabledTexture fun(self: Frame, t)
---@field CreateTexture fun(self: Frame, name, layer) : table
---@field SetHighlightTexture fun(self: Frame, tex)
---@field Show fun(self: Frame)
---@field Hide fun(self: Frame)
---@field Disable fun(self: Frame)
---@field Enable fun(self: Frame)
---@field CreateFontString fun(self: Frame, name, layer, template) : table

-- Basic function stubs
---@type fun(frameType: string, name: string?, parent: table?, template: string?): Frame
local CreateFrame

-- Provide a GameTooltip-like interface
---@class GameTooltipFrame: Frame
---@field SetOwner fun(self: GameTooltipFrame, owner: Frame, anchor: string)
---@field ClearLines fun(self: GameTooltipFrame)
---@field AddLine fun(self: GameTooltipFrame, text: string, ...) -- optional color args or more
---@field Show fun(self: GameTooltipFrame)
---@field Hide fun(self: GameTooltipFrame)
---@type GameTooltipFrame
local GameTooltip

-- Frame globals used by the addon
---@class PaperDollFrameClass: Frame
---@field __XIVEquipHook boolean
---@type PaperDollFrameClass
local PaperDollFrame

---@class CharacterFrameClass: Frame
---@field __XIVEquipHook boolean
---@type CharacterFrameClass
local CharacterFrame

---@type Frame
local UIParent
---@type Frame
local CharacterFramePortrait

-- C-style tables
C_Item = C_Item or {}
---@type table
local C_Item
---@type table
local C_Timer

---@type fun(...): any
local GetItemStats
---@type fun(...): any
local GetItemInfo
---@type fun(...): any
local GetDetailedItemLevelInfo
---@type fun(...): any
---@type fun(...): any
local UnitName
---@type fun(): any
local geterrorhandler

---@type table
local SlashCmdList
---@type string
local SLASH_XIVE1
---@type string
local SLASH_XIVEQUIP1

---@type fun(...)
local print

-- Dropdown/menu helpers (signatures only)
---@type fun(frame: Frame, w: number)
local UIDropDownMenu_SetWidth
---@type fun(frame: Frame, fn: fun(self: Frame, level: number))
local UIDropDownMenu_Initialize
---@type fun(): table
local UIDropDownMenu_CreateInfo
---@type fun(frame: Frame, text: string)
local UIDropDownMenu_SetText
---@type fun(info: table, level: number)
local UIDropDownMenu_AddButton

-- Widget types
---@class FontString: Frame
---@field SetText fun(self: FontString, text: string)
---@field SetPoint fun(self: FontString, point: string, ...)
---@field SetWidth fun(self: FontString, w: number)
---@field SetJustifyH fun(self: FontString, h: string)

---@class CheckButton: Frame
---@field Text FontString
---@field SetChecked fun(self: CheckButton, v: boolean)
---@field GetChecked fun(self: CheckButton): boolean
---@field SetScript fun(self: CheckButton, script: string, fn: fun(self: CheckButton))

-- Specialization / class helpers
---@type fun(): number?
local GetSpecialization
---@type fun(idx: number): any
local GetSpecializationInfo
---@type fun(unit: string): (number, string)
local UnitClass
---@type fun(): boolean
local IsDualWielding

-- Bag constants & container API (signatures only)
---@type number
local NUM_BAG_SLOTS
---@type table
local C_Container
---@type fun(bag: number): number
local C_Container_GetContainerNumSlots
---@type fun(bag: number, slot: number): table?
local C_Container_GetContainerItemInfo
---@type fun(bag: number, slot: number): string?
local C_Container_GetContainerItemLink

---@type fun(itemID: number): (string, string, number, number, string)
local GetItemInfoInstant

-- ItemLocation type (signed for LSP only)
---@class ItemLocation
---@field bagID number
---@field slotIndex number
---@type fun(bag: number, slot: number): ItemLocation
local ItemLocation_CreateFromBagAndSlot

-- Combat / equipment-set helpers
---@type fun(): boolean
local InCombatLockdown

---@class EquipmentSetAPI
---@field GetEquipmentSetID fun(name: string): number?
---@field CreateEquipmentSet fun(name: string, icon: number)
---@field SaveEquipmentSet fun(id: number)
---@field ModifyEquipmentSetIcon fun(id: number, icon: number)
---@type EquipmentSetAPI
local C_EquipmentSet

---@type fun(unit: string, slotId: number): string?
local GetInventoryItemLink

_G.UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
_G.UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
_G.UIDropDownMenu_SetText = UIDropDownMenu_SetText
_G.UIDropDownMenu_AddButton = UIDropDownMenu_AddButton

-- Settings module (addon-specific helper API)
Settings = Settings or {}
function Settings.RegisterCanvasLayoutCategory(panel, title) return { panel = panel, title = title } end

function Settings.RegisterAddOnCategory(category) end

_G.Settings = Settings

-- Cursor / equipment helpers (editor-only signatures)
---@type fun(): nil
local ClearCursor
---@type fun(invSlot: any): nil
local EquipCursorItem

-- Time helper
---@type fun(): number
local GetTime

-- Simple logger typing for the project's Log usage (accepts varargs)
---@class Logger
---@field Debug fun(...: any)
---@field Info fun(...: any)
---@field Warn fun(...: any)
---@field Error fun(...: any)
---@type Logger
local Log

-- Minimal XIVEquip global with typed Log to help files that do local Log = XIVEquip.Log or ...
---@class XIVEquipGlobal
---@field Log Logger
---@type XIVEquipGlobal
_G.XIVEquip = _G.XIVEquip or {}
_G.XIVEquip.Log = _G.XIVEquip.Log or Log

-- Project debug global used by Automation/SpecSwitch.lua
---@type boolean
_G.XIVEquip_DebugAutoSpec = _G.XIVEquip_DebugAutoSpec or false

-- Export editor-only signatures as globals so the LSP/linters see them
_G.ClearCursor = ClearCursor
_G.EquipCursorItem = EquipCursorItem
_G.GetTime = GetTime
_G.Log = Log

-- Realm helper
---@type fun(): string
local GetRealmName
_G.GetRealmName = GetRealmName

-- Tooltip info API (editor-only signatures)
---@class TooltipInfoAPI
---@field GetHyperlink fun(link: string): table?
---@type TooltipInfoAPI
local C_TooltipInfo
_G.C_TooltipInfo = C_TooltipInfo

-- Pawn-related editor globals (signatures only)
---@type table
local Pawn
---@type fun(keyOrName: string): table?
local PawnGetScaleValues
---@type fun(keyOrName: string): table?
local PawnGetProviderScaleValues
_G.Pawn = _G.Pawn or Pawn
_G.PawnGetScaleValues = _G.PawnGetScaleValues or PawnGetScaleValues
_G.PawnGetProviderScaleValues = _G.PawnGetProviderScaleValues or PawnGetProviderScaleValues
_G.PawnPlayerFullName = _G.PawnPlayerFullName or ""

-- Project debug global used in multiple files
---@type boolean
_G.XIVEquip_Debug = _G.XIVEquip_Debug or false
