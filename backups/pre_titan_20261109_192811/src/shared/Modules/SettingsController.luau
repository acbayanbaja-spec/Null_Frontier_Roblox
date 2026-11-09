local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local SettingsController = {}

local currentSettings = {
    MusicVolume = 0.7,
    SFXVolume = 0.8,
    CameraSensitivity = 1.0,
    QualityMode = "Cinematic" -- "Cinematic" | "Balanced" | "Performance"
}

local function getSoundGroup(name: string)
    local master = SoundService:FindFirstChild("MasterAudio")
    return master and master:FindFirstChild(name)
end

function SettingsController.Get()
    return currentSettings
end

function SettingsController.SetMusicVolume(vol: number)
    currentSettings.MusicVolume = math.clamp(vol, 0, 1)
    local mg = getSoundGroup("MusicGroup")
    if mg then
        mg.Volume = currentSettings.MusicVolume
    end
end

function SettingsController.SetSFXVolume(vol: number)
    currentSettings.SFXVolume = math.clamp(vol, 0, 1)
    local sg = getSoundGroup("SFXGroup")
    if sg then
        sg.Volume = currentSettings.SFXVolume
    end
end

function SettingsController.SetCameraSensitivity(sens: number)
    currentSettings.CameraSensitivity = math.clamp(sens, 0.2, 2.0)
    pcall(function()
        UserInputService.MouseDeltaSensitivity = currentSettings.CameraSensitivity
    end)
end

function SettingsController.SetQualityMode(mode: string)
    if mode ~= "Cinematic" and mode ~= "Balanced" and mode ~= "Performance" then
        return
    end
    currentSettings.QualityMode = mode
    
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    
    if mode == "Cinematic" then
        if bloom then bloom.Enabled = true; bloom.Intensity = 0.6 end
        if cc then cc.Enabled = true end
        if atmosphere then atmosphere.Density = 0.35 end
    elseif mode == "Balanced" then
        if bloom then bloom.Enabled = true; bloom.Intensity = 0.3 end
        if cc then cc.Enabled = true end
        if atmosphere then atmosphere.Density = 0.25 end
    elseif mode == "Performance" then
        if bloom then bloom.Enabled = false end
        if cc then cc.Enabled = false end
        if atmosphere then atmosphere.Density = 0.15 end
    end
end

-- Initialize with defaults
SettingsController.SetMusicVolume(currentSettings.MusicVolume)
SettingsController.SetSFXVolume(currentSettings.SFXVolume)
SettingsController.SetCameraSensitivity(currentSettings.CameraSensitivity)
SettingsController.SetQualityMode(currentSettings.QualityMode)

return SettingsController
