if SERVER then
	AddCSLuaFile()	
end

SWEP.HoldType               = "normal"

if CLIENT then
   SWEP.PrintName           = "Basketball"
   SWEP.Slot                = 8
   SWEP.ViewModelFlip       = false
   SWEP.ViewModelFOV        = 90
   SWEP.DrawCrosshair       = false
	
   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "Throw the Passketball at other players to buff them."
   };

   SWEP.Icon                = "vgui/ttt/icon_hoop"
   SWEP.IconLetter          = "j"

   function SWEP:Initialize()
		self:AddTTT2HUDHelp("Hit players to stun them.", "Dunk on a Terry!")
	end
end

SWEP.Base                   = "weapon_tttbase"

SWEP.UseHands               = true
SWEP.ViewModel              = "models/c_ballin.mdl"
SWEP.WorldModel             = ""

SWEP.Primary.Damage         = 0
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Delay          = 2
SWEP.Primary.Ammo           = "none"
SWEP.Primary.Sound			= "weapons/iceaxe/iceaxe_swing1.wav"

SWEP.Kind                   = WEAPON_CLASS
SWEP.AllowDrop              = false -- Is the player able to drop the swep

SWEP.IsSilent               = false

-- Pull out faster than standard guns
SWEP.DeploySpeed            = 2

--Removes the SWEP on death or drop
function SWEP:OnDrop()
	self:Remove()
end


--------------------------------------------------------------------------------------------------------------------
--				PRIMARY
--					ATTACK
--------------------------------------------------------------------------------------------------------------------

-- Override original primary attack
function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )	
    self:SendWeaponAnim( ACT_VM_ISHOOT )
    self:ThrowBall()
    self:GetOwner():ViewPunch( Angle( 2, 0, 0 ) )
end

-- Function that will be called whenever collision happens
local function PhysCallback( ent, data )
	-- Bouncing noise
	if data.Speed > 100 then
		ent:EmitSound( "ballin/bounce.wav" )
	end
	
	-- Do stuff to hit player
	local hitEnt = data.HitEntity
    if IsValid(hitEnt) and hitEnt:IsPlayer() then
        hitEnt:ViewPunch( Angle( 100, 100, 100 ) )
		hitEnt:TakeDamage( 20, ent, ent )
    end
end

-- Function to create a Basketball and throw it
function SWEP:ThrowBall()
	-- Get the owner of the weapon for later
	local owner = self:GetOwner()
	if not owner:IsValid() then return end

	-- Play the throwing sound
	self:EmitSound( self.Primary.Sound )
	
	-- Tell client to go home
	if CLIENT then return end

	-- Create a prop_physics entity
	local entThrown = ents.Create( "prop_physics" )
	if not entThrown:IsValid() then return end

	-- Set the entity's model
	entThrown:SetModel( "models/basketball.mdl" )

	-- Get where player is looking
	local aimvec = owner:GetAimVector()
	local pos = aimvec * 20 -- This creates a new vector object
    pos:Add( owner:EyePos()) -- This translates the local aimvector to world coordinates

	-- Set the position of the ball
	entThrown:SetPos( pos )

	-- Set the angles to the player'e eye angles
    entThrown:SetAngles( owner:EyeAngles() )

	-- Set ball to be owned by thrower
    if(IsValid(self:GetOwner())) then
        entThrown:SetOwner(self:GetOwner())
    end
	
	-- Spawn the ball
    entThrown:SetNWBool("isBasketBall", true)
	entThrown:Spawn()
	
	-- Update size for proper collision
	entThrown:SetModelScale(1.3)

	-- Create a trail
	local trail = util.SpriteTrail( entThrown, 0, Color( 255, 255, 255, 100), false, 10, 1, 1.2, 1 / ( 15 + 1 ) * 0.5, "trails/smoke" )
	
	-- Add sound for bouncing
	entThrown:AddCallback( "PhysicsCollide", PhysCallback )
	
	-- Get physics object for ball
	local phys = entThrown:GetPhysicsObject()
	if not phys:IsValid() then entThrown:Remove() return end
 
	-- Apply force to the ball
    phys:SetMaterial("gmod_bouncy")
	phys:SetMass(55)
    aimvec:Mul( 100000 )
	aimvec:Add(Vector(0, 0, -2500)) 
	phys:ApplyForceCenter(aimvec)
    phys:ApplyForceCenter( Vector(0, 0, -2500) )
    owner:SetVelocity(Vector(0, 0, -300))
	
	-- Remove ball after 10 seconds
	timer.Simple( 10, function()
		if entThrown and entThrown:IsValid() then 
			local pos = entThrown:GetPos()
			local effectData = EffectData()
			effectData:SetOrigin(pos)
			util.Effect("balloon_pop", effectData)
			entThrown:Remove() 
		end
	end)
end

--------------------------------------------------------------------------------------------------------------------
--				SECONDARY
--					ATTACK
--------------------------------------------------------------------------------------------------------------------

-- CODE BASICALLY COPIED FROM TTT_CONFGRENADE_PROJ.LUA
local function DiscombobExplosion(pos, pusher)
   local radius = 400
   local phys_force = 1500
   local push_force = 256

   -- pull physics objects and push players
   for k, target in ipairs(ents.FindInSphere(pos, radius)) do
      if IsValid(target) then
         local tpos = target:LocalToWorld(target:OBBCenter())
         local dir = (tpos - pos):GetNormal()
         local phys = target:GetPhysicsObject()

         if target:IsPlayer() and (not target:IsFrozen()) and ((not target.was_pushed) or target.was_pushed.t != CurTime()) then

            -- always need an upwards push to prevent the ground's friction from
            -- stopping nearly all movement
            dir.z = math.abs(dir.z) + 1

            local push = dir * push_force

            -- try to prevent excessive upwards force
            local vel = target:GetVelocity() + push
            vel.z = math.min(vel.z, push_force)

            target:SetVelocity(vel)

         elseif IsValid(phys) then
            phys:ApplyForceCenter(dir * phys_force * 10)
         end
      end
   end

   local phexp = ents.Create("env_physexplosion")
   if IsValid(phexp) then
      phexp:SetPos(pos)
      phexp:SetKeyValue("magnitude", 500) --max
      phexp:SetKeyValue("radius", radius)
      -- 1 = no dmg, 2 = push ply, 4 = push radial, 8 = los, 16 = viewpunch
      phexp:SetKeyValue("spawnflags", 1 + 2 + 16)
      phexp:Spawn()
      phexp:Fire("Explode", "", 0.2)
   end
   
   local effect = EffectData()
   effect:SetStart(pos)
   effect:SetOrigin(pos)
   util.Effect("Explosion", effect, true, true)
   util.Effect("cball_explode", effect, true, true)
end

-- Override original secondary attack
function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	
	-- Tell client to go home
	if CLIENT then return end
	
	-- check if on ground
	if not owner:IsOnGround() then return end
	
	-- make him jump super high
    owner:SetVelocity((owner:GetUp() + Vector(0, 0, 200)) * 200)
	owner.IsDunkJumping = true
	owner:EmitSound( "ballin/boing.wav" )
	self:SendWeaponAnim( ACT_VM_SECONDARYATTACK )
	
	-- on landing cause explosion
	hook.Add("Move", "CheckLanding", function(ply, mv)
		-- only for active players
		if not ply:IsActive() then return end
		-- only for hoopers
		if ply:GetSubRole() == ROLE_HOOPER then
			-- do landing logic
			if ply:IsOnGround() and not ply.WasOnGround and ply.IsDunkJumping then
				print(ply:Nick() .. " has landed from a DUNK JUMP.")
				ply.IsDunkJumping = false
				ply:EmitSound( "ballin/dunk.wav" )
				DiscombobExplosion(ply:GetPos(), ply)
				self:SendWeaponAnim( ACT_VM_IDLE )
			end
			ply.WasOnGround = ply:IsOnGround()
		end
	end)
end