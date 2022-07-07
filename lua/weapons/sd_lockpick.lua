AddCSLuaFile()

SWEP.Author = "crester"
SWEP.PrintName = "SD Lock Pick"
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip = false
SWEP.ViewModel = Model("models/weapons/c_crowbar.mdl")
SWEP.WorldModel = Model("models/weapons/w_crowbar.mdl")
SWEP.UseHands = true

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.RequiredTime = 10

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Lockpicking")
	self:NetworkVar("Float", 0, "StartTime")
	self:NetworkVar("Float", 1, "EndTime")
	self:NetworkVar("Float", 2, "NextSound")
	self:NetworkVar("Entity", 0, "Door")
end

function SWEP:Holster()
	self:SetLockpicking(false)
	self:SetDoor(nil)
	return true
end

function SWEP:DrawHUD()
	if not self:GetLockpicking() or self:GetEndTime() == 0 then
		return
	end

	local w = ScrW()
	local h = ScrH()
	local x, y, width, height = w / 2 - w / 10, h / 2 - 60, w / 5, h / 15
	draw.RoundedBox(4, x, y, width, height, Color(10, 10, 10, 120))

	local time = self:GetEndTime() - self:GetStartTime()
	local curtime = CurTime() - self:GetStartTime()
	local status = math.Clamp(curtime / time, 0, 1)
	local BarWidth = status * (width - 16)
	local cornerRadius = math.Min(4, BarWidth / 3 * 2 - BarWidth / 3 * 2 % 2)
	draw.RoundedBox(cornerRadius, x + 8, y + 8, BarWidth, height - 16, Color(255 - (status * 255), 0 + (status * 255), 0, 255))
end

if SERVER then
	function SWEP:PrimaryAttack()
		self:SetNextPrimaryFire(CurTime() + 2)

		if self:GetLockpicking() then
			return
		end

		self:GetOwner():LagCompensation(true)
		local trace = self:GetOwner():GetEyeTrace()
		self:GetOwner():LagCompensation(false)
		local ent = trace.Entity

		if not IsValid(ent) or not ent:IsSmartDoor() or trace.HitPos:DistToSqr(self:GetOwner():GetShootPos()) > 10000 or ent:GetNWBool("SmartDoorOpened") then
			return
		end

		self:SetHoldType("pistol")
		self:SetLockpicking(true)
		self:SetDoor(ent)
		self:SetStartTime(CurTime())
		self:SetEndTime(CurTime() + self.RequiredTime)
	end

	function SWEP:SecondaryAttack()
		self:PrimaryAttack()
	end

	function SWEP:Succeed()
		self:SetHoldType("normal")

		local ent = self:GetDoor()
		self:SetLockpicking(false)
		self:SetDoor(nil)

		if not IsValid(ent) then
			return
		end

		if ent:IsSmartDoor() then
			ent:OpenSmartDoor()
		end
	end

	function SWEP:Fail()
		self:SetLockpicking(false)
		self:SetHoldType("normal")
		self:SetDoor(nil)
	end
end

function SWEP:Think()
	if not self:GetLockpicking() or self:GetEndTime() == 0 then
		return
	end

	if not IsValid(self) or not IsValid(self:GetOwner()) or not self:GetOwner():Alive() then
		self:Fail()
		return
	end

	if CurTime() >= self:GetNextSound() then
		self:SetNextSound(CurTime() + 1)
		self:EmitSound("weapons/357/357_reload" .. math.random(3, 4) .. ".wav", 50, 100)
	end

	if SERVER then
		local trace = self:GetOwner():GetEyeTrace()
		if not IsValid(trace.Entity) or trace.Entity ~= self:GetDoor() or trace.HitPos:DistToSqr(self:GetOwner():GetShootPos()) > 10000 then
			self:Fail()
		elseif self:GetEndTime() <= CurTime() then
			self:Succeed()
		end
	end
end