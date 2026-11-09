-- InventoryManager for NULL FRONTIER
-- Server-authoritative inventory, marketplace transactions, and cosmetic avatar equipment.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local ItemConfig = require(NullFrontier.Config.ItemConfig)
local Remotes = NullFrontier.Remotes
local PurchaseMarketplaceItemRF = Remotes:WaitForChild("PurchaseMarketplaceItem")
local EquipInventoryItemRF = Remotes:WaitForChild("EquipInventoryItem")
local UnequipInventorySlotRF = Remotes:WaitForChild("UnequipInventorySlot")
local GetInventoryDataRF = Remotes:WaitForChild("GetInventoryData")
local EquipmentChangedNotificationRE = Remotes:WaitForChild("EquipmentChangedNotification")

local InventoryManager = {}

-- Visual Builders for Compatible Avatar Attachments
local function createCosmeticModel(item, character): Model?
    local slot = item.Slot
    local rootPart = nil
    local offsetCF = CFrame.identity
    
    if slot == "Head" then
        rootPart = character:FindFirstChild("Head")
        if item.ModelType == "Visor" then
            offsetCF = CFrame.new(0, 0.15, -0.58)
        else -- Halo
            offsetCF = CFrame.new(0, 1.1, 0)
        end
    elseif slot == "Body" then
        rootPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        offsetCF = CFrame.new(0, 0.15, -0.62)
    elseif slot == "Back" then
        rootPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        offsetCF = CFrame.new(0, 0.35, 0.65)
    elseif slot == "Weapon" then
        rootPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
        offsetCF = CFrame.new(0, -1.1, -0.15) * CFrame.Angles(math.rad(-90), 0, 0)
    end
    
    if not rootPart then return nil end
    
    local model = Instance.new("Model")
    model.Name = "Equip_" .. slot
    
    local p = Instance.new("Part")
    p.Name = "Visual"
    p.Material = Enum.Material.Neon
    p.Color = item.AccentColor or Color3.fromRGB(0, 220, 255)
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    
    if item.ModelType == "Visor" then
        p.Size = Vector3.new(1.18, 0.26, 0.45)
    elseif item.ModelType == "Halo" then
        p.Size = Vector3.new(1.2, 0.1, 1.2)
        p.Shape = Enum.PartType.Cylinder
    elseif item.ModelType == "ChestCore" then
        p.Size = Vector3.new(0.65, 0.65, 0.22)
    elseif item.ModelType == "Wings" then
        p.Size = Vector3.new(2.4, 0.8, 0.15)
    elseif item.ModelType == "Blade" then
        p.Size = Vector3.new(0.18, 2.6, 0.18)
    else
        p.Size = Vector3.new(0.6, 0.8, 0.3)
    end
    
    p.CFrame = rootPart.CFrame * offsetCF
    p.Parent = model
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = p
    weld.Part1 = rootPart
    weld.Parent = p
    
    model.PrimaryPart = p
    model.Parent = character
    return model
end

-- Apply Equipment Visual on Character
function InventoryManager.ApplyEquipmentVisual(player: Player, slot: string, itemId: string)
    local character = player.Character
    if not character then return end
    
    InventoryManager.RemoveEquipmentVisual(player, slot)
    
    local item = ItemConfig.Items[itemId]
    if not item or item.Slot == "Emote" then return end
    
    createCosmeticModel(item, character)
end

-- Remove Equipment Visual from Character
function InventoryManager.RemoveEquipmentVisual(player: Player, slot: string)
    local character = player.Character
    if not character then return end
    
    local existing = character:FindFirstChild("Equip_" .. slot)
    if existing then
        existing:Destroy()
    end
end

-- Re-apply all equipped items upon character spawn
function InventoryManager.SetupCharacterEquipment(player: Player, character: Model)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile or not profile.Equipment then return end
    
    task.defer(function()
        for slot, itemId in pairs(profile.Equipment) do
            if itemId and ItemConfig.Items[itemId] then
                InventoryManager.ApplyEquipmentVisual(player, slot, itemId)
            end
        end
    end)
end

-- 1. Purchase Item with Earned Frontier Credits
function InventoryManager.PurchaseItem(player: Player, itemId: string): (boolean, string, table?)
    local item = ItemConfig.Items[itemId]
    if not item then
        return false, "Item does not exist in Frontier registry"
    end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then
        return false, "Operative session data unavailable"
    end
    
    if not profile.Inventory then profile.Inventory = {} end
    if profile.Inventory[itemId] then
        return false, "Operative already owns this item"
    end
    
    local ProgressionManager = require(script.Parent:WaitForChild("ProgressionManager"))
    local deductSuccess, newBalance, msg = ProgressionManager.DeductCredits(player, item.PriceCredits, "Purchase_" .. itemId)
    if not deductSuccess then
        return false, "Insufficient Frontier Credits (Requires " .. tostring(item.PriceCredits) .. " CR)"
    end
    
    -- Grant ownership atomically
    profile.Inventory[itemId] = {
        ItemId = itemId,
        AcquiredAt = os.time(),
        Quantity = 1
    }
    
    print(string.format("[InventoryManager] %s successfully acquired '%s' for %d CR (Balance: %d CR).", player.Name, item.Name, item.PriceCredits, newBalance))
    
    local RewardNotificationRE = Remotes:WaitForChild("RewardNotification")
    RewardNotificationRE:FireClient(player, "ACQUIRED: " .. item.Name, 0, 0)
    
    return true, "Acquisition confirmed", profile.Inventory[itemId]
end

-- 2. Equip Owned Item
function InventoryManager.EquipItem(player: Player, itemId: string): (boolean, string, table?)
    local item = ItemConfig.Items[itemId]
    if not item then return false, "Invalid item" end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return false, "Session unavailable" end
    
    if not profile.Inventory or not profile.Inventory[itemId] then
        return false, "Cannot equip unowned equipment"
    end
    
    if not profile.Equipment then profile.Equipment = {} end
    profile.Equipment[item.Slot] = itemId
    
    InventoryManager.ApplyEquipmentVisual(player, item.Slot, itemId)
    EquipmentChangedNotificationRE:FireAllClients(player, item.Slot, itemId, true)
    
    print(string.format("[InventoryManager] Operative %s equipped '%s' to slot [%s].", player.Name, item.Name, item.Slot))
    return true, "Equipped", profile.Equipment
end

-- 3. Unequip Slot
function InventoryManager.UnequipSlot(player: Player, slot: string): (boolean, string, table?)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile or not profile.Equipment then return false, "Session unavailable" end
    
    profile.Equipment[slot] = nil
    InventoryManager.RemoveEquipmentVisual(player, slot)
    EquipmentChangedNotificationRE:FireAllClients(player, slot, "", false)
    
    print(string.format("[InventoryManager] Operative %s unequipped slot [%s].", player.Name, slot))
    return true, "Unequipped", profile.Equipment
end

-- RemoteFunction Bindings
PurchaseMarketplaceItemRF.OnServerInvoke = function(player: Player, itemId: string)
    if type(itemId) ~= "string" then return false, "Invalid argument" end
    return InventoryManager.PurchaseItem(player, itemId)
end

EquipInventoryItemRF.OnServerInvoke = function(player: Player, itemId: string)
    if type(itemId) ~= "string" then return false, "Invalid argument" end
    return InventoryManager.EquipItem(player, itemId)
end

UnequipInventorySlotRF.OnServerInvoke = function(player: Player, slot: string)
    if type(slot) ~= "string" then return false, "Invalid argument" end
    return InventoryManager.UnequipSlot(player, slot)
end

GetInventoryDataRF.OnServerInvoke = function(player: Player)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return nil end
    
    return {
        Inventory = profile.Inventory or {},
        Equipment = profile.Equipment or {},
        Catalog = ItemConfig.Items,
        Monetization = ItemConfig.Monetization
    }
end

return InventoryManager
