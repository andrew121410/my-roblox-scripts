local PathFinder = {}
PathFinder.__index = PathFinder

local PathfindingService = game:GetService("PathfindingService")

function PathFinder.new(person, isRandom, isFighter, isGunner)
  local newPathFinder = {}
  setmetatable(newPathFinder, PathFinder)

  newPathFinder.person = person
  newPathFinder.humanoid = person:WaitForChild("Humanoid")
  newPathFinder.personRoot = person:WaitForChild("HumanoidRootPart")

  newPathFinder.waypoints = {}
  newPathFinder.currentWaypointIndex = 0

  newPathFinder.path = PathfindingService:CreatePath({
    ["AgentHeight"] = 5,
    ["AgentRadius"] = 5
  })

  newPathFinder.PathBlockedEvent = nil
  newPathFinder.PathWaypointReached = nil

  --Custom events
  newPathFinder.onPathComplete = Instance.new("BindableEvent")

  --Temp
  newPathFinder.position = nil
  newPathFinder.isRunning = false

  --Settings config
  newPathFinder.debug = true
  newPathFinder.isRandom = isRandom
  newPathFinder.isFighter = isFighter
  newPathFinder.isGunner = isGunner

  return newPathFinder
end

function PathFinder.walkRandomly(self)
  if self.isRandom == false then
    print("walkRandomly tried to run but isRandom is false.")
    return 0
  end

  local xRand = math.random(-100, 100)
  local zRand = math.random(-100, 100)
  local goal = self.person.HumanoidRootPart.Position + Vector3.new(xRand,0,zRand)

  self.waypoints = {}
  self.currentWaypointIndex = 0
  self.path:ComputeAsync(self.personRoot.Position, goal)
  wait(0.5)
  self.waypoints = self.path:GetWaypoints()

  local tDis
  if self.path.Status == Enum.PathStatus.Success then
    for _, waypoint in ipairs(self.waypoints) do

      if self.debug then
        local part = Instance.new("Part")
        part.Shape = "Ball"
        part.Material = "Neon"
        part.Size = Vector3.new(0.6, 0.6, 0.6)
        part.Position = waypoint.Position
        part.Anchored = true
        part.CanCollide = false
        part.Parent = game.Workspace
      end

      --Jump
      if waypoint.Action == Enum.PathWaypointAction.Jump then
        self.humanoid.Jump = true
      end

      self.currentWaypointIndex = self.currentWaypointIndex + 1
      self.humanoid:MoveTo(waypoint.Position)

      --https://devforum.roblox.com/t/pathfinding-npc-seems-to-be-hopping/120893/7
      repeat
        tDis = (waypoint.Position - self.personRoot.Position).magnitude
        wait()
      until
      tDis <= 5
    end --End of for()
    print("DONE")
  else
    self.humanoid:MoveTo(self.personRoot.Position)
  end
end

function PathFinder.followPath(self, position)
  self.isRunning = true
  self.position = position

  self.waypoints = {}
  self.currentWaypointIndex = 0
  self.path:ComputeAsync(self.personRoot.Position, position)
  wait(0.5)
  self.waypoints = self.path:GetWaypoints()

  local stuck = 0
  if self.path.Status == Enum.PathStatus.Success then
    for _, waypoint in ipairs(self.waypoints) do
      stuck = 0

      if self.debug then
        local part = Instance.new("Part")
        part.Shape = "Ball"
        part.Material = "Neon"
        part.Size = Vector3.new(0.6, 0.6, 0.6)
        part.Position = waypoint.Position
        part.Anchored = true
        part.CanCollide = false
        part.Parent = game.Workspace
      end

      --Jump
      if waypoint.Action == Enum.PathWaypointAction.Jump then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
      end

      self.currentWaypointIndex = self.currentWaypointIndex + 1
      self.humanoid:MoveTo(waypoint.Position)

      local done = false
      local event = self.humanoid.MoveToFinished:Connect(function(isDone)
      done = isDone
      end)

      --https://scriptinghelpers.org/questions/26996/using-an-event-for-a-repeat-until
      repeat
        stuck = stuck + 1
        if stuck == 30 then
          print("Got stuck {FIXING}")
          break
        end
        wait()
      until done == true
      event:Disconnect()
    end --End of for()
  else
    self.humanoid:MoveTo(self.personRoot.Position)
  end
end

function PathFinder.checkSight(self,target)
  local ray = Ray.new(self.personRoot.Position, (target.Position - self.personRoot.Position).Unit * 40)
  local hit,position = workspace:FindPartOnRayWithIgnoreList(ray, {script.Parent})
  if hit then
    if hit:IsDescendantOf(target.Parent) and math.abs(hit.Position.Y - self.personRoot.Position.Y) < 3 then
      print("I can see the target")
      return true
    end
  end
  return false
end

function PathFinder.findTarget(self)
  local dist = 50
  local target = nil
  local potentialTargets = {}
  local seeTargets = {}
  for i,v in ipairs(workspace:GetChildren()) do
    local human = v:FindFirstChild("Humanoid")
    local torso = v:FindFirstChild("Torso") or v:FindFirstChild("HumanoidRootPart")
    if human and torso and v.Name ~= script.Parent.Name then
      if (self.personRoot.Position - torso.Position).magnitude < dist and human.Health > 0 then
        table.insert(potentialTargets,torso)
      end
    end
  end
  if #potentialTargets > 0 then
    for i,v in ipairs(potentialTargets) do
      if self.checkSight(self,v) then
        table.insert(seeTargets, v)
      elseif #seeTargets == 0 and (self.personRoot.Position - v.Position).magnitude < dist then
        target = v
        dist = (self.personRoot.Position - v.Position).magnitude
      end
    end
  end
  if #seeTargets > 0 then
    dist = 200
    for i,v in ipairs(seeTargets) do
      if (self.personRoot.Position - v.Position).magnitude < dist then
        target = v
        dist = (self.personRoot.Position - v.Position).magnitude
      end
    end
  end
  if target then
    if math.random(20) == 1 then
      print("Sound should be playing.")
    end
  end
  return target
end

--Runs every time it goes to a waypoint.
function PathFinder.onWaypointReached(self,reached)
  if reached and self.currentWaypointIndex >= #self.waypoints and self.isRandom == true then
    wait(0.5)
    print("Recaculating the path.>>>>")
    self:walkRandomly()
  elseif reached and self.currentWaypointIndex >= #self.waypoints and self.isRandom == false then
    self.isRunning = false
    self.onPathComplete:Fire(self, self.position)
    self.position = nil
    print("Path is now done.")
  end

end

--Runs when path was blocked.
function PathFinder.onPathBlocked(self,index)
  print("onPathBlocked has been ran........")
  if self.isRandom == true then
    wait(0.5)
    self:walkRandomly()
  else
    if index > self.currentWaypointIndex then
      self:followPath()
    end
  end
end

function PathFinder.setUpEvents(self)
  self.PathBlockedEvent = self.path.Blocked:Connect(function(index)
  self.onPathBlocked(self,index)
  end)
  self.PathWaypointReached = self.humanoid.MoveToFinished:Connect(function(index)
  self.onWaypointReached(self,index)
  end)
end

return PathFinder