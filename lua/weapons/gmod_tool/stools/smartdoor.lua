TOOL.Category = "Construction"
TOOL.Name = "#Smart Door"

TOOL.ClientConVar["title"] = ""
TOOL.ClientConVar["friends"] = "1"
TOOL.ClientConVar["material"] = "1"
TOOL.ClientConVar["sound"] = "1"

TOOL.Materials = {
	[1] = "models/wireframe",
	[2] = "sprites/heatwave",
	[3] = "Models/effects/comball_tape",
	[4] = "Models/effects/splodearc_sheet",
	[5] = "Models/effects/vol_light001",
	[6] = "models/props_combine/stasisshield_sheet",
	[7] = "models/props_combine/portalball001_sheet",
	[8] = "models/props_combine/com_shield001a",
	[9] = "models/props_c17/frostedglass_01a"
}

TOOL.Sounds = {
	[1] = "doors/doorstop1.wav",
	[2] = "npc/turret_floor/retract.wav",
	[3] = "npc/roller/mine/combine_mine_deactivate1.wav",
	[4] = "npc/roller/mine/combine_mine_deploy1.wav",
	[5] = "npc/roller/mine/rmine_taunt1.wav",
	[6] = "npc/scanner/scanner_nearmiss2.wav",
	[7] = "npc/scanner/scanner_siren1.wav",
	[8] = "npc/barnacle/barnacle_gulp1.wav",
	[9] = "npc/barnacle/barnacle_gulp2.wav",
	[10] = "npc/combine_gunship/attack_start2.wav",
	[11] = "npc/combine_gunship/attack_stop2.wav",
	[12] = "npc/dog/dog_pneumatic1.wav",
	[13] = "npc/dog/dog_pneumatic2.wav"
}

local ENTITY = FindMetaTable("Entity")

function ENTITY:IsSmartDoor()
    return self:GetNWBool("SmartDoor")
end

function ENTITY:IsSmartDoorOpened()
    return self:GetNWBool("SmartDoorOpened")
end

if CLIENT then
	language.Add("tool.smartdoor.name", "Smart Door")
	language.Add("tool.smartdoor.desc", "Allows to create a smart door")
	language.Add("tool.smartdoor.0", "Press R on the prop to customize it's whitelist")

	surface.CreateFont("smartdoor_hud", {size = 26, weight = 300, antialias = true, extended = true, font = "Roboto Condensed"})
	surface.CreateFont("smartdoor_hud_shadow", {size = 27, weight = 300, antialias = true, extended = true, blursize = 1.5, font = "Roboto Condensed"})

	local function PrettyText(text, font, x, y, color, xalign, yalign)
		draw.SimpleText(text, font .. "_shadow", x + 1, y + 1, ColorAlpha(color_black, 120), xalign, yalign and yalign or TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, x + 1, y + 1, ColorAlpha(color_black, 150), xalign, yalign and yalign or TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, x, y, color, xalign, yalign and yalign or TEXT_ALIGN_TOP)
	end

	local mat, lp, tr = Material("icon16/lock.png")
	hook.Add("HUDPaint", "Smart Door", function()
		lp = LocalPlayer() 
		tr = lp:GetEyeTraceNoCursor()
		if IsValid(tr.Entity) and tr.HitPos:DistToSqr(lp:EyePos()) < 22500 then
			local ent = tr.Entity
			if not ent:IsSmartDoor() then 
				return 
			end

			surface.SetFont("smartdoor_hud")
			local name = ent:GetNWString("DoorTitle")
			local name_size = surface.GetTextSize(name)

			local extra = 0
			if name_size == 0 then
				extra = 6
			end

			PrettyText(name, "smartdoor_hud", ScrW() / 2 - 8, ScrH() / 1.6, color_white, TEXT_ALIGN_CENTER)

			if not ent:GetNWBool("SmartDoorOpened") then
				surface.SetMaterial(mat)
				surface.SetDrawColor(color_white)
				surface.DrawTexturedRect(ScrW() / 2 + name_size / 2 - extra, ScrH() / 1.6 + 6, 16, 16)
			end
		end
	end)

	local lp, wep
	hook.Add("PreDrawHalos", "Smart Door", function()
		lp = LocalPlayer()
		wep = lp:GetActiveWeapon()

		if (!IsValid(wep)) or (wep:GetClass() ~= "gmod_tool") or (lp:GetTool("smartdoor") == nil) then
			return
		end

		local doors = {}
		for _, ent in pairs(ents.FindByClass("prop_physics")) do
			if (ent == lp:GetEyeTrace().Entity) and (ent:GetNWEntity("DoorOwner") == lp) and (ent:IsSmartDoor()) then 
				table.insert(doors, ent)
			end
		end
		halo.Add(doors, HSVToColor(150, 1, 1), 2, 2, 2)

		if CPPI then
			local props = {}
			for _, ent in pairs(ents.FindByClass("prop_physics")) do
				if (ent == lp:GetEyeTrace().Entity) and (ent:CPPIGetOwner() == lp) and (!ent:IsSmartDoor()) then
					table.insert(props, ent)
				end
			end
			halo.Add(props, color_white, 2, 2, 2)
		end
	end)

	net.Receive("Smart Door Get Whitelist", function()
		local ent = net.ReadEntity()
		local tbl = net.ReadTable()

		local menu = DermaMenu()

		local add = menu:AddSubMenu("Add to whitelist")
		for _, pl in pairs(player.GetAll()) do
			if table.HasValue(tbl, pl) or pl == LocalPlayer() then
				continue
			end

			add:AddOption(pl:Name(), function()
				net.Start("Smart Door Add Whitelist")
					net.WriteEntity(ent)
					net.WriteEntity(pl)
				net.SendToServer()
			end):SetIcon("icon16/user.png")
		end

		local remove = menu:AddSubMenu("Remove from whitelist")
		for _, pl in pairs(tbl) do
			remove:AddOption(pl:Name(), function()
				net.Start("Smart Door Remove Whitelist")
					net.WriteEntity(ent)
					net.WriteEntity(pl)
				net.SendToServer()
			end):SetIcon("icon16/user_green.png")
		end

		menu:MakePopup()
		menu:Open()
	end)
end

if SERVER then
	util.AddNetworkString("Smart Door Get Whitelist")
	util.AddNetworkString("Smart Door Set Whitelist")
	util.AddNetworkString("Smart Door Add Whitelist")
	util.AddNetworkString("Smart Door Remove Whitelist")

	net.Receive("Smart Door Set Whitelist", function(_, sender)
		local ent = net.ReadEntity()
		local tbl = net.ReadTable()

		if not IsValid(ent) or not IsValid(sender) or ent.OwnerID ~= sender:UniqueID() then
			return
		end

		ent.Whitelist = tbl
	end)

	net.Receive("Smart Door Add Whitelist", function(_, sender)
		local ent = net.ReadEntity()
		local pl = net.ReadEntity()

		if not IsValid(sender) or ent.OwnerID ~= sender:UniqueID() then
			return
		end

		if not IsValid(ent) or not ent:IsSmartDoor() or table.HasValue(ent.Whitelist, pl) then
			return
		end

		table.insert(ent.Whitelist, pl)
	end)

	net.Receive("Smart Door Remove Whitelist", function(_, sender)
		local ent = net.ReadEntity()
		local pl = net.ReadEntity()

		if not IsValid(sender) or ent.OwnerID ~= sender:UniqueID() then
			return
		end

		if not IsValid(ent) or not ent:IsSmartDoor() or not table.HasValue(ent.Whitelist, pl) then
			return
		end

		table.RemoveByValue(ent.Whitelist, pl)
	end)

	function ENTITY:SetSmartDoor(bool)
		self:SetNWBool("SmartDoor", bool)

		self.OwnerID = 1

		self.Whitelist = {}

		self.DoorSound = ""
		self.DoorMaterial = ""

		self.InitialMaterial = self:GetMaterial()
	end

	function ENTITY:OpenSmartDoor()
		if not self:IsSmartDoor() then
			return
		end

		local material 
		if self.DoorMaterial ~= "" then
			material = self.DoorMaterial
		else
			material = "models/wireframe"
		end

		if self:GetNWBool("SmartDoorOpened") then
			local trace = {
				start = self:GetPos(),
				endpos = self:GetPos(),
				mins = self:OBBMins(),
				maxs = self:OBBMaxs(),
				filter = self
			}

			local tr = util.TraceHull(trace)
			if tr.Entity and not tr.Entity:IsWorld() and IsValid(tr.Entity) then
				return
			end

			self:SetCollisionGroup(COLLISION_GROUP_NONE)
			self:SetNWBool("SmartDoorOpened", false)
			self:SetMaterial(self.InitialMaterial)
		else
			self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
			self:SetNWBool("SmartDoorOpened", true)
			self:SetMaterial(material)
		end

		if self.DoorSound ~= "" then
			self:EmitSound(self.DoorSound)
		end
	end

	hook.Add("PlayerUse", "Smart Door", function(pl, ent)
		if not timer.Exists("Smart Door Cooldown #" .. ent:EntIndex()) then
			if pl:GetPos():Distance(ent:GetPos()) > 130 or pl:InVehicle() or not IsValid(ent) or not ent:IsSmartDoor() then
				return
			end
			if ent:GetNWEntity("DoorOwner") == pl or table.HasValue(ent.Whitelist, pl) then
				ent:OpenSmartDoor()
				timer.Create("Smart Door Cooldown #" .. ent:EntIndex(), 0.25, 1, function() end)
				return
			end
		end
	end)

	hook.Add("PlayerInitialSpawn", "Smart Door", function(pl)
		for _, ent in pairs(ents.GetAll()) do
			if not ent:IsSmartDoor() then
				continue
			end
			if ent.OwnerID == pl:UniqueID() then
				ent:SetNWEntity("DoorOwner", pl)
			end
		end
	end)
end

local MatNum = #TOOL.Materials
local SoundNum = #TOOL.Sounds
function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Text = "Smart Door", 
		Description = "Enter the title of your smart door" 
	})

	local Entry = vgui.Create("DTextEntry")
	panel:AddItem(Entry)

	local Button = vgui.Create("DButton")
	Button:SetText("Save title")
	Button.DoClick = function()
		RunConsoleCommand("smartdoor_title", Entry:GetValue() or "")
	end
	
	panel:AddItem(Button)
 
	panel:AddControl("Slider", {
	    Label = "Material",
	    Min = "1",
	    Max = tostring(MatNum),
	    Command = "smartdoor_material"
	})

	panel:AddControl("Slider", {
	    Label = "Sound",
	    Min = "1",
	    Max = tostring(SoundNum),
	    Command = "smartdoor_sound"
	})

	panel:AddControl("CheckBox", {
		Label = "Steam friends are able to open the door",
		Command = "smartdoor_friends"
	})
end

function TOOL:LeftClick(tr)
	if not tr.Entity or not IsValid(tr.Entity) or tr.HitWorld then
		return false
	end

	local ent = tr.Entity
	if ent:IsSmartDoor() or ent:GetClass() ~= "prop_physics" then
		return false
	end

	if SERVER then
		ent:SetSmartDoor(true)
		ent:SetNWString("DoorTitle", self:GetClientInfo("title"))
		ent:SetNWEntity("DoorOwner", self:GetOwner())

		ent.DoorMaterial = self.Materials[self:GetClientNumber("material", 1)]
		ent.DoorSound = self.Sounds[self:GetClientNumber("sound", 1)]
		ent.OwnerID = self:GetOwner():UniqueID()
	end

	if CLIENT then
		if self:GetClientNumber("friends", 1) == 1 then
			local tbl = {}
			for _, pl in pairs(player.GetAll()) do
				if pl:GetFriendStatus() == "friend" then
					table.insert(tbl, pl)
				end
			end

			net.Start("Smart Door Set Whitelist")
				net.WriteEntity(ent)
				net.WriteTable(tbl)
			net.SendToServer()
		end
	end

	return true
end
 
function TOOL:RightClick(tr)
	if not tr.Entity or not IsValid(tr.Entity) or tr.HitWorld then
		return false
	end

	local ent = tr.Entity
	if not ent:IsSmartDoor() or ent:GetClass() ~= "prop_physics" then
		return false
	end

	if SERVER then
		if ent:GetNWBool("SmartDoorOpened") then
			ent:OpenSmartDoor()
		end

		ent:SetSmartDoor(false)
		ent:SetNWEntity("DoorOwner", nil)
	end

	return true
end

function TOOL:Reload(tr)
	if not tr.Entity or not IsValid(tr.Entity) or tr.HitWorld then
		return false
	end

	local ent = tr.Entity
	if not ent:IsSmartDoor() or ent:GetClass() ~= "prop_physics" then
		return false
	end

	if self:GetOwner() ~= ent:GetNWEntity("DoorOwner") then
		return false
	end

	if SERVER then
		net.Start("Smart Door Get Whitelist")
			net.WriteEntity(ent)
			net.WriteTable(ent.Whitelist)
		net.Send(self:GetOwner())
	end

	return true
end
