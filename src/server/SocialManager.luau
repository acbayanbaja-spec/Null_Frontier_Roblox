local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local GetPlayerProfileRF = Remotes:WaitForChild("GetPlayerProfile")
local SendPartyInviteRE = Remotes:WaitForChild("SendPartyInvite")
local PartyInviteReceivedRE = Remotes:WaitForChild("PartyInviteReceived")
local RespondPartyInviteRE = Remotes:WaitForChild("RespondPartyInvite")
local LeavePartyRE = Remotes:WaitForChild("LeaveParty")
local PartyUpdateRE = Remotes:WaitForChild("PartyUpdate")

local SocialManager = {}

-- State
local parties = {}           -- partyId -> { Leader = player, Members = {player1, player2, ...}, MaxSize = 4 }
local playerParty = {}       -- player -> partyId
local inviteCooldowns = {}   -- "senderId_targetId" -> timestamp
local pendingInvites = {}    -- targetUserId -> { senderUserId = number, partyId = string, expiry = number }

-- Helper: Broadcast Party Roster to all members
local function broadcastParty(partyId: string)
    local party = parties[partyId]
    if not party then return end
    
    local memberList = {}
    for _, member in ipairs(party.Members) do
        if member and member.Parent then
            table.insert(memberList, {
                UserId = member.UserId,
                Username = member.Name,
                DisplayName = member.DisplayName,
                Level = member:GetAttribute("Level") or 1,
                IsLeader = (member == party.Leader),
                Health = member.Character and member.Character:FindFirstChildOfClass("Humanoid") and member.Character.Humanoid.Health or 100,
                MaxHealth = member:GetAttribute("MaxHealth") or 100,
                Shield = member:GetAttribute("Shield") or 100
            })
        end
    end
    
    for _, member in ipairs(party.Members) do
        if member and member.Parent then
            PartyUpdateRE:FireClient(member, partyId, memberList)
        end
    end
end

-- 1. Profile Request Handler (Server-Authoritative)
function SocialManager.GetProfileData(requestingPlayer: Player, targetUserId: number)
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then
        return nil, "Operative offline or not in sector"
    end
    
    local pId = playerParty[target]
    local isLeader = false
    local squadSize = 0
    if pId and parties[pId] then
        isLeader = (parties[pId].Leader == target)
        squadSize = #parties[pId].Members
    end
    
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    
    return {
        UserId = target.UserId,
        Username = target.Name,
        DisplayName = target.DisplayName,
        Level = target:GetAttribute("Level") or 1,
        Status = target:GetAttribute("Status") or "OPERATIVE: ACTIVE",
        Credits = target:GetAttribute("Credits") or 0,
        AccountAge = target.AccountAge,
        InParty = pId ~= nil,
        IsLeader = isLeader,
        PartySize = squadSize,
        Health = hum and hum.Health or 100,
        MaxHealth = hum and hum.MaxHealth or 100,
        Shield = target:GetAttribute("Shield") or 100
    }
end

GetPlayerProfileRF.OnServerInvoke = function(player: Player, targetUserId: number)
    if type(targetUserId) ~= "number" then return nil end
    return SocialManager.GetProfileData(player, targetUserId)
end

-- 2. Party Invite Logic
SendPartyInviteRE.OnServerEvent:Connect(function(sender: Player, targetUserId: number)
    if type(targetUserId) ~= "number" or targetUserId == sender.UserId then return end
    
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then return end
    
    -- Rate limit: 6 seconds cooldown between invites to same target
    local cdKey = tostring(sender.UserId) .. "_" .. tostring(target.UserId)
    local now = os.clock()
    if inviteCooldowns[cdKey] and (now - inviteCooldowns[cdKey] < 6.0) then
        return
    end
    inviteCooldowns[cdKey] = now
    
    -- Check party status
    local partyId = playerParty[sender]
    if not partyId then
        -- Create new party
        partyId = "Party_" .. HttpService:GenerateGUID(false):sub(1, 8)
        parties[partyId] = {
            Leader = sender,
            Members = {sender},
            MaxSize = 4
        }
        playerParty[sender] = partyId
        sender:SetAttribute("PartyId", partyId)
        broadcastParty(partyId)
    end
    
    local party = parties[partyId]
    if not party or party.Leader ~= sender then
        return -- Only leader can invite
    end
    if #party.Members >= party.MaxSize then
        return -- Party full
    end
    if playerParty[target] == partyId then
        return -- Already in squad
    end
    
    -- Record pending invite with 15s expiry
    pendingInvites[target.UserId] = {
        senderUserId = sender.UserId,
        partyId = partyId,
        expiry = now + 15
    }
    
    PartyInviteReceivedRE:FireClient(target, sender.UserId, sender.DisplayName, sender:GetAttribute("Level") or 1)
end)

-- 3. Party Response Logic
RespondPartyInviteRE.OnServerEvent:Connect(function(target: Player, senderUserId: number, accepted: boolean)
    local invite = pendingInvites[target.UserId]
    if not invite or invite.senderUserId ~= senderUserId then return end
    
    local now = os.clock()
    if now > invite.expiry then
        pendingInvites[target.UserId] = nil
        return -- Expired
    end
    
    local partyId = invite.partyId
    local party = parties[partyId]
    pendingInvites[target.UserId] = nil
    
    if accepted and party and #party.Members < party.MaxSize then
        -- If target is in another party, leave it first
        SocialManager.LeaveParty(target)
        
        table.insert(party.Members, target)
        playerParty[target] = partyId
        target:SetAttribute("PartyId", partyId)
        broadcastParty(partyId)
    end
end)

-- 4. Leave Party Logic
function SocialManager.LeaveParty(player: Player)
    local partyId = playerParty[player]
    if not partyId then return end
    
    local party = parties[partyId]
    playerParty[player] = nil
    player:SetAttribute("PartyId", nil)
    PartyUpdateRE:FireClient(player, "", {})
    
    if not party then return end
    
    -- Remove from member list
    for idx, member in ipairs(party.Members) do
        if member == player then
            table.remove(party.Members, idx)
            break
        end
    end
    
    if #party.Members == 0 then
        -- Disband
        parties[partyId] = nil
    else
        -- If leader left, promote next member
        if party.Leader == player then
            party.Leader = party.Members[1]
        end
        broadcastParty(partyId)
    end
end

LeavePartyRE.OnServerEvent:Connect(function(player: Player)
    SocialManager.LeaveParty(player)
end)

-- Disconnect Cleanup
Players.PlayerRemoving:Connect(function(player: Player)
    SocialManager.LeaveParty(player)
    pendingInvites[player.UserId] = nil
    for k in pairs(inviteCooldowns) do
        if string.find(k, "^" .. tostring(player.UserId) .. "_") or string.find(k, "_" .. tostring(player.UserId) .. "$") then
            inviteCooldowns[k] = nil
        end
    end
end)

-- 5. Attach High-Tech Overhead Hologram & Proximity Interaction Prompt to Character
function SocialManager.SetupCharacterSocial(player: Player, character: Model)
    local head = character:WaitForChild("Head", 10)
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if not head or not hrp then return end
    
    -- Clean previous if any
    local oldTag = head:FindFirstChild("OverheadTag")
    if oldTag then oldTag:Destroy() end
    local oldPrompt = hrp:FindFirstChild("SocialPrompt")
    if oldPrompt then oldPrompt:Destroy() end
    
    -- High-Tech Overhead Billboard
    local bb = Instance.new("BillboardGui")
    bb.Name = "OverheadTag"
    bb.Size = UDim2.new(0, 160, 0, 48)
    bb.StudsOffset = Vector3.new(0, 2.8, 0)
    bb.MaxDistance = 55
    bb.AlwaysOnTop = false
    bb.Adornee = head
    bb.Parent = head
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = bb
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameLabel"
    nameLbl.Size = UDim2.new(1, 0, 0, 22)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = player.DisplayName
    nameLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
    nameLbl.TextSize = 14
    nameLbl.TextStrokeColor3 = Color3.fromRGB(5, 10, 20)
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.Parent = frame
    
    local badgeLbl = Instance.new("TextLabel")
    badgeLbl.Name = "BadgeLabel"
    badgeLbl.Position = UDim2.new(0, 0, 0, 22)
    badgeLbl.Size = UDim2.new(1, 0, 0, 16)
    badgeLbl.BackgroundTransparency = 1
    badgeLbl.Font = Enum.Font.GothamMedium
    badgeLbl.Text = string.format("@%s â€¢ LVL %d", player.Name, player:GetAttribute("Level") or 1)
    badgeLbl.TextColor3 = Color3.fromRGB(0, 220, 255)
    badgeLbl.TextSize = 11
    badgeLbl.TextStrokeColor3 = Color3.fromRGB(5, 10, 20)
    badgeLbl.TextStrokeTransparency = 0.4
    badgeLbl.Parent = frame
    
    -- Update overhead when level changes
    player:GetAttributeChangedSignal("Level"):Connect(function()
        badgeLbl.Text = string.format("@%s â€¢ LVL %d", player.Name, player:GetAttribute("Level") or 1)
    end)
    
    -- Social ProximityPrompt on HumanoidRootPart
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "SocialPrompt"
    prompt.ActionText = "Tactical Comm"
    prompt.ObjectText = "Operative: " .. player.DisplayName
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = true
    prompt.Parent = hrp
end

return SocialManager
