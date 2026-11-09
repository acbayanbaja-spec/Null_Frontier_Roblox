-- MarketplaceController for NULL FRONTIER
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local PurchaseMarketplaceItemRF = Remotes:WaitForChild("PurchaseMarketplaceItem")
local EquipInventoryItemRF = Remotes:WaitForChild("EquipInventoryItem")
local UnequipInventorySlotRF = Remotes:WaitForChild("UnequipInventorySlot")
local GetInventoryDataRF = Remotes:WaitForChild("GetInventoryData")
local EquipmentChangedNotificationRE = Remotes:WaitForChild("EquipmentChangedNotification")

local gui = script.Parent
local mainContainer = gui:WaitForChild("MainContainer")
local toggleBtn = mainContainer:WaitForChild("MarketplaceToggleBtn")
local modal = mainContainer:WaitForChild("MarketplaceModal")
local header = modal:WaitForChild("Header")
local balText = header:WaitForChild("BalanceBadge"):WaitForChild("BalanceText")
local navFrame = modal:WaitForChild("NavFrame")
local btnTabMarket = navFrame:WaitForChild("BtnTabMarket")
local btnTabInventory = navFrame:WaitForChild("BtnTabInventory")
local btnTabMonetization = navFrame:WaitForChild("BtnTabMonetization")
local filterBar = modal:WaitForChild("FilterBar")
local marketScroll = modal:WaitForChild("MarketScroll")
local inventoryContainer = modal:WaitForChild("InventoryContainer")
local equipPanel = inventoryContainer:WaitForChild("EquipPanel")
local eqSlotsList = equipPanel:WaitForChild("SlotsList")
local ownedScroll = inventoryContainer:WaitForChild("OwnedScroll")
local monetizationContainer = modal:WaitForChild("MonetizationContainer")
local monScroll = monetizationContainer:WaitForChild("MonetizationScroll")
local closeBtn = modal:WaitForChild("CloseBtn")

local currentTab = "Market"
local currentFilter = "ALL"

local RARITY_COLORS = {
    Common = Color3.fromRGB(160, 175, 195),
    Rare = Color3.fromRGB(0, 220, 255),
    Epic = Color3.fromRGB(190, 130, 255),
    Legendary = Color3.fromRGB(255, 200, 50)
}

-- Balance updates
local function updateBalance()
    local cr = player:GetAttribute("Credits") or 0
    balText.Text = string.format("CREDITS: %d CR", cr)
end
player:GetAttributeChangedSignal("Credits"):Connect(updateBalance)
updateBalance()

-- Modal Animation
local function openModal()
    updateBalance()
    modal.Position = UDim2.new(0.5, 0, 0.54, 0)
    modal.BackgroundTransparency = 1
    modal.Visible = true
    TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.15
    }):Play()
end

local function closeModal()
    local tw = TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.54, 0),
        BackgroundTransparency = 1
    })
    tw:Play()
    tw.Completed:Connect(function()
        modal.Visible = false
    end)
end

-- Render Marketplace Items
local function renderMarket(data)
    for _, c in ipairs(marketScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local catalog = data.Catalog or {}
    local owned = data.Inventory or {}
    
    local itemsList = {}
    for id, item in pairs(catalog) do
        if currentFilter == "ALL" or string.upper(item.Category) == currentFilter then
            table.insert(itemsList, item)
        end
    end
    table.sort(itemsList, function(a, b)
        local ownedA = owned[a.Id] ~= nil
        local ownedB = owned[b.Id] ~= nil
        if ownedA ~= ownedB then return not ownedA end
        return a.PriceCredits < b.PriceCredits
    end)
    
    for idx, item in ipairs(itemsList) do
        local isOwned = owned[item.Id] ~= nil
        local rColor = RARITY_COLORS[item.Rarity] or Color3.fromRGB(0, 220, 255)
        
        local card = Instance.new("Frame")
        card.Name = "Item_" .. item.Id
        card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
        card.BackgroundTransparency = 0.3
        card.LayoutOrder = idx
        card.Parent = marketScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = isOwned and Color3.fromRGB(30, 45, 40) or rColor
        stroke.Thickness = 1.2
        
        -- Rarity & Slot Badge
        local badge = Instance.new("TextLabel")
        badge.Position = UDim2.new(0, 8, 0, 8)
        badge.Size = UDim2.new(1, -16, 0, 14)
        badge.BackgroundTransparency = 1
        badge.Font = Enum.Font.GothamBold
        badge.Text = string.format("[%s // %s]", item.Rarity:upper(), item.Slot:upper())
        badge.TextColor3 = rColor
        badge.TextSize = 8
        badge.TextXAlignment = Enum.TextXAlignment.Left
        badge.Parent = card
        
        -- Title
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Position = UDim2.new(0, 8, 0, 22)
        titleLbl.Size = UDim2.new(1, -16, 0, 16)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = item.Name
        titleLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card
        
        -- Description
        local descLbl = Instance.new("TextLabel")
        descLbl.Position = UDim2.new(0, 8, 0, 38)
        descLbl.Size = UDim2.new(1, -16, 0, 34)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = item.Description
        descLbl.TextColor3 = Color3.fromRGB(160, 185, 210)
        descLbl.TextSize = 8
        descLbl.TextWrapped = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextYAlignment = Enum.TextYAlignment.Top
        descLbl.Parent = card
        
        -- Price & Action Button
        local actBtn = Instance.new("TextButton")
        actBtn.Position = UDim2.new(0, 8, 1, -34)
        actBtn.Size = UDim2.new(1, -16, 0, 26)
        actBtn.Parent = card
        Instance.new("UICorner", actBtn).CornerRadius = UDim.new(0, 4)
        
        if isOwned then
            actBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 26)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = "âœ“ OWNED"
            actBtn.TextColor3 = Color3.fromRGB(100, 180, 140)
            actBtn.TextSize = 9
            actBtn.AutoButtonColor = false
        else
            actBtn.BackgroundColor3 = Color3.fromRGB(20, 35, 52)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = string.format("BUY: %d CR", item.PriceCredits)
            actBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
            actBtn.TextSize = 9
            
            actBtn.Activated:Connect(function()
                actBtn.Text = "TRANSACTING..."
                local success, msg = PurchaseMarketplaceItemRF:InvokeServer(item.Id)
                if success then
                    actBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 26)
                    actBtn.Text = "âœ“ OWNED"
                    actBtn.TextColor3 = Color3.fromRGB(100, 180, 140)
                    actBtn.AutoButtonColor = false
                    updateBalance()
                else
                    actBtn.Text = "INSUFFICIENT CR"
                    actBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
                    task.wait(1.5)
                    actBtn.Text = string.format("BUY: %d CR", item.PriceCredits)
                    actBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
                end
            end)
        end
    end
end

-- Render Inventory & Equipment
local function renderInventory(data)
    -- 1. Render Left Side: Equipped Slots
    for _, c in ipairs(eqSlotsList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local catalog = data.Catalog or {}
    local equipped = data.Equipment or {}
    local owned = data.Inventory or {}
    
    local SLOTS = {"Head", "Body", "Back", "Weapon", "Emote"}
    for idx, slotName in ipairs(SLOTS) do
        local slotRow = Instance.new("Frame")
        slotRow.Name = "Slot_" .. slotName
        slotRow.Size = UDim2.new(1, 0, 0, 52)
        slotRow.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
        slotRow.BackgroundTransparency = 0.4
        slotRow.LayoutOrder = idx
        slotRow.Parent = eqSlotsList
        Instance.new("UICorner", slotRow).CornerRadius = UDim.new(0, 6)
        
        local tag = Instance.new("TextLabel")
        tag.Position = UDim2.new(0, 8, 0, 6)
        tag.Size = UDim2.new(1, -70, 0, 12)
        tag.BackgroundTransparency = 1
        tag.Font = Enum.Font.GothamBold
        tag.Text = string.format("SLOT: [%s]", slotName:upper())
        tag.TextColor3 = Color3.fromRGB(0, 210, 255)
        tag.TextSize = 8
        tag.TextXAlignment = Enum.TextXAlignment.Left
        tag.Parent = slotRow
        
        local equippedItemId = equipped[slotName]
        local item = equippedItemId and catalog[equippedItemId] or nil
        
        local itemText = Instance.new("TextLabel")
        itemText.Position = UDim2.new(0, 8, 0, 20)
        itemText.Size = UDim2.new(1, -76, 0, 24)
        itemText.BackgroundTransparency = 1
        itemText.Font = Enum.Font.GothamBold
        itemText.Text = item and item.Name or "[EMPTY]"
        itemText.TextColor3 = item and Color3.fromRGB(240, 248, 255) or Color3.fromRGB(120, 135, 155)
        itemText.TextSize = 9
        itemText.TextXAlignment = Enum.TextXAlignment.Left
        itemText.Parent = slotRow
        
        if item then
            local unequipBtn = Instance.new("TextButton")
            unequipBtn.AnchorPoint = Vector2.new(1, 0.5)
            unequipBtn.Position = UDim2.new(1, -6, 0.5, 0)
            unequipBtn.Size = UDim2.new(0, 60, 0, 24)
            unequipBtn.BackgroundColor3 = Color3.fromRGB(40, 24, 30)
            unequipBtn.Font = Enum.Font.GothamBold
            unequipBtn.Text = "UNEQUIP"
            unequipBtn.TextColor3 = Color3.fromRGB(255, 120, 130)
            unequipBtn.TextSize = 8
            unequipBtn.Parent = slotRow
            Instance.new("UICorner", unequipBtn).CornerRadius = UDim.new(0, 4)
            
            unequipBtn.Activated:Connect(function()
                UnequipInventorySlotRF:InvokeServer(slotName)
                local fresh = GetInventoryDataRF:InvokeServer()
                if fresh then renderInventory(fresh) end
            end)
        end
    end
    
    -- 2. Render Right Side: Owned Items
    for _, c in ipairs(ownedScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local ownedList = {}
    for id, record in pairs(owned) do
        if catalog[id] then
            table.insert(ownedList, catalog[id])
        end
    end
    table.sort(ownedList, function(a, b) return a.Name < b.Name end)
    
    for idx, item in ipairs(ownedList) do
        local isEquipped = (equipped[item.Slot] == item.Id)
        local rColor = RARITY_COLORS[item.Rarity] or Color3.fromRGB(0, 220, 255)
        
        local card = Instance.new("Frame")
        card.Name = "Owned_" .. item.Id
        card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
        card.BackgroundTransparency = 0.3
        card.LayoutOrder = idx
        card.Parent = ownedScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = isEquipped and Color3.fromRGB(0, 255, 170) or rColor
        stroke.Thickness = 1.2
        
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Position = UDim2.new(0, 8, 0, 8)
        nameLbl.Size = UDim2.new(1, -16, 0, 16)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = item.Name
        nameLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
        nameLbl.TextSize = 10
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card
        
        local slotTag = Instance.new("TextLabel")
        slotTag.Position = UDim2.new(0, 8, 0, 24)
        slotTag.Size = UDim2.new(1, -16, 0, 14)
        slotTag.BackgroundTransparency = 1
        slotTag.Font = Enum.Font.Gotham
        slotTag.Text = string.format("%s // %s", item.Rarity:upper(), item.Slot:upper())
        slotTag.TextColor3 = rColor
        slotTag.TextSize = 8
        slotTag.TextXAlignment = Enum.TextXAlignment.Left
        slotTag.Parent = card
        
        local actBtn = Instance.new("TextButton")
        actBtn.Position = UDim2.new(0, 8, 1, -30)
        actBtn.Size = UDim2.new(1, -16, 0, 22)
        actBtn.Parent = card
        Instance.new("UICorner", actBtn).CornerRadius = UDim.new(0, 4)
        
        if isEquipped then
            actBtn.BackgroundColor3 = Color3.fromRGB(18, 38, 28)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = "â˜… EQUIPPED"
            actBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
            actBtn.TextSize = 9
            actBtn.AutoButtonColor = false
        else
            actBtn.BackgroundColor3 = Color3.fromRGB(20, 35, 52)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = "EQUIP"
            actBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
            actBtn.TextSize = 9
            
            actBtn.Activated:Connect(function()
                EquipInventoryItemRF:InvokeServer(item.Id)
                local fresh = GetInventoryDataRF:InvokeServer()
                if fresh then renderInventory(fresh) end
            end)
        end
    end
end

-- Render Monetization View
local function renderMonetization(data)
    for _, c in ipairs(monScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local mon = data.Monetization or {}
    local passes = mon.GamePasses or {}
    local products = mon.DeveloperProducts or {}
    
    local list = {}
    for k, v in pairs(passes) do table.insert(list, {Kind = "GamePass", Data = v}) end
    for k, v in pairs(products) do table.insert(list, {Kind = "Product", Data = v}) end
    
    for idx, entry in ipairs(list) do
        local p = entry.Data
        local card = Instance.new("Frame")
        card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
        card.BackgroundTransparency = 0.3
        card.LayoutOrder = idx
        card.Parent = monScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = Color3.fromRGB(50, 65, 85)
        
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Position = UDim2.new(0, 10, 0, 8)
        titleLbl.Size = UDim2.new(1, -20, 0, 16)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = string.format("[%s] %s", entry.Kind:upper(), p.Name)
        titleLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card
        
        local descLbl = Instance.new("TextLabel")
        descLbl.Position = UDim2.new(0, 10, 0, 24)
        descLbl.Size = UDim2.new(1, -20, 0, 26)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = p.Description or string.format("Grants %d Frontier Credits instantly.", p.Amount or 0)
        descLbl.TextColor3 = Color3.fromRGB(160, 185, 210)
        descLbl.TextSize = 8
        descLbl.TextWrapped = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = card
        
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Position = UDim2.new(0, 10, 1, -24)
        statusLbl.Size = UDim2.new(1, -20, 0, 18)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Font = Enum.Font.GothamBold
        statusLbl.Text = "ðŸ”’ UNCONFIGURED IN PLACE SETTINGS"
        statusLbl.TextColor3 = Color3.fromRGB(255, 180, 50)
        statusLbl.TextSize = 8
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusLbl.Parent = card
    end
end

-- Refresh Active View
local function refreshView()
    local data = GetInventoryDataRF:InvokeServer()
    if not data then return end
    
    if currentTab == "Market" then
        renderMarket(data)
    elseif currentTab == "Inventory" then
        renderInventory(data)
    else
        renderMonetization(data)
    end
end

-- Tab Switcher
local function setTab(tabName)
    currentTab = tabName
    if tabName == "Market" then
        btnTabMarket.BackgroundColor3 = Color3.fromRGB(25, 38, 56)
        btnTabMarket.TextColor3 = Color3.fromRGB(0, 230, 255)
        btnTabInventory.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabInventory.TextColor3 = Color3.fromRGB(160, 180, 200)
        btnTabMonetization.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabMonetization.TextColor3 = Color3.fromRGB(160, 180, 200)
        filterBar.Visible = true
        marketScroll.Visible = true
        inventoryContainer.Visible = false
        monetizationContainer.Visible = false
    elseif tabName == "Inventory" then
        btnTabInventory.BackgroundColor3 = Color3.fromRGB(25, 38, 56)
        btnTabInventory.TextColor3 = Color3.fromRGB(0, 255, 170)
        btnTabMarket.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabMarket.TextColor3 = Color3.fromRGB(160, 180, 200)
        btnTabMonetization.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabMonetization.TextColor3 = Color3.fromRGB(160, 180, 200)
        filterBar.Visible = false
        marketScroll.Visible = false
        inventoryContainer.Visible = true
        monetizationContainer.Visible = false
    else
        btnTabMonetization.BackgroundColor3 = Color3.fromRGB(25, 38, 56)
        btnTabMonetization.TextColor3 = Color3.fromRGB(255, 200, 50)
        btnTabMarket.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabMarket.TextColor3 = Color3.fromRGB(160, 180, 200)
        btnTabInventory.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabInventory.TextColor3 = Color3.fromRGB(160, 180, 200)
        filterBar.Visible = false
        marketScroll.Visible = false
        inventoryContainer.Visible = false
        monetizationContainer.Visible = true
    end
    refreshView()
end

btnTabMarket.Activated:Connect(function() setTab("Market") end)
btnTabInventory.Activated:Connect(function() setTab("Inventory") end)
btnTabMonetization.Activated:Connect(function() setTab("Monetization") end)

-- Category Filter Connections
for _, btn in ipairs(filterBar:GetChildren()) do
    if btn:IsA("TextButton") then
        btn.Activated:Connect(function()
            currentFilter = string.gsub(btn.Name, "Filter_", "")
            for _, b in ipairs(filterBar:GetChildren()) do
                if b:IsA("TextButton") then
                    b.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
                    b.TextColor3 = Color3.fromRGB(140, 160, 180)
                end
            end
            btn.BackgroundColor3 = Color3.fromRGB(22, 35, 50)
            btn.TextColor3 = Color3.fromRGB(0, 230, 255)
            refreshView()
        end)
    end
end

local function toggleModal()
    if modal.Visible then
        closeModal()
    else
        openModal()
        refreshView()
    end
end

toggleBtn.Activated:Connect(toggleModal)
closeBtn.Activated:Connect(closeModal)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
        if input.KeyCode == Enum.KeyCode.I and not modal.Visible then
            setTab("Inventory")
        end
        toggleModal()
    end
end)

EquipmentChangedNotificationRE.OnClientEvent:Connect(function()
    if modal.Visible and currentTab == "Inventory" then
        refreshView()
    end
end)

print("[NullFrontier] MarketplaceController initialized.")
