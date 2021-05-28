while true do

    local drone = component.proxy(component.list('drone')())
    local modem = component.proxy(component.list('modem')())
    local nav = component.proxy(component.list('navigation')())

    modem.open(1)
    
   -- Here you have to define width and length of your field, radar range(in blocks) of waypoint detection, and the minimum energy (when drone goes charging)
  
    local fieldWidth = 0
    local fieldLength = 0
    local minEnergy = 3500
    local radar = 500
    
  ------------------------------------------------------------------------------
  
    local currPos = 0
    local moveUsed = false
    local rowHarvested = false
    local rowsDone = 0
    local harvestDone= false
    local isDetected = false
    local isWater = false
    local droneDirX = 0
    local droneDirZ = 0

    local initialized = false
    local destLoc

    local function locate()
      local waypoints = nav.findWaypoints(radar)
      for i=1, waypoints.n do
        if waypoints[i].label == droneDest then
          destX = waypoints[i].position[1]
          destY = waypoints[i].position[2]
          destZ = waypoints[i].position[3]
        end
        destLoc = {destX, destY, destZ}
      end
    end

    local function detection()
      local isBlock, blockType = drone.detect(0)
      if isBlock == true and blockType == "passable" then
        isDetected = true
      else
        isDetected = false
      end
    end

    local function detectFluid()
      if drone.compareFluid(0) == true then
        isWater = true
      else
        isWater = false
      end
    end

    local function awaitArrival()
      while drone.getVelocity() > 0 do end
    end

    local function measureField()
      repeat
        drone.move(0,0,droneDirZ)
        awaitArrival()
        detection()
        fieldLength = fieldLength+1
      until isDetected == false
      awaitArrival()
      droneDest = "farm"
      locate(droneDest)
      local startZ = destLoc[3]+droneDirZ
      drone.move(destLoc[1],destLoc[2],startZ)

      awaitArrival()

      repeat
        drone.move(droneDirX,0,0)
        awaitArrival()
        detection()
        if isDetected == false then
          drone.move(0,-1,0)
          awaitArrival()
          detectFluid()
          drone.move(0,1,0)
        end
        fieldWidth = fieldWidth+1
      until isDetected == false and isWater == false
      fieldLength = fieldLength-1
    end

    local function detectField()
      drone.move(0,0,1)
      awaitArrival()
      detection()
      if isDetected == true then
        droneDirZ = 1
        drone.move(1,0,0)
        awaitArrival()
        drone.setStatusText("Iwashere")
        detection()
        if isDetected == true then
          droneDirX = 1
        else
          droneDirX = -1
        end
        droneDest = "farm"
        locate(droneDest)
        drone.move(destLoc[1],destLoc[2],destLoc[3])
      else
        droneDirZ = -1
        drone.move(-1,0,-1)
        awaitArrival()
        detection()
        if isDetected == true then
          droneDirX = -1
        else
          droneDirX = 1
        end
        droneDest = "farm"
        locate(droneDest)
        drone.move(destLoc[1],destLoc[2],destLoc[3])
      end
      awaitArrival()
      measureField()
    end

    local function charge()
      droneDest = "base"
      locate(droneDest)
      drone.move(destLoc[1],destLoc[2],destLoc[3])
      local charged = false
      while computer.energy() < computer.maxEnergy() do
        charged = false
      end
      charged = true
      return charged
    end

    -- local function checkCharge()
    --   local energyLevel = computer.energy()
    --   local hasEnergy
    --   if energyLevel > 3500 then
    --     hasEnergy = true
    --   else
    --     charge()
    --     if charge() == true then
    --       hasEnergy = true        
    --     end
    --   end
    --   return hasEnergy
    -- end

    local function init()
      droneDest = "farm"
      locate(droneDest)
      if computer.energy() >= minEnergy then
        drone.move(destLoc[1],destLoc[2],destLoc[3])
        awaitArrival()
          detectField()
      else
        charge()
        if charge() == true then
            init()
        end
      end
      while drone.getVelocity() > 0 do
        initialized = false
      end
      initialized = true
    end
    
    local function dropItems(x)
      drone.select(x)
      drone.drop(2)
    end
    
    local function resetHarvest()
        currPos = 0
        moveUsed = false
        rowHarvested = false
        rowsDone = 0
        harvestDone= false
    end

    local function harvestCompleted()
      if rowsDone == fieldWidth then
        droneDest = "chest"
        locate(droneDest)
        drone.move(destLoc[1],destLoc[2],destLoc[3])
        while drone.getVelocity() > 0 do
          harvestDone = false
        end
        harvestDone = true
      end
      if harvestDone == true then
        local invSize = drone.inventorySize()
        for i=1, invSize do
          dropItems(i)
        end
      end
    end    

    local function updatePos()
      currPos = currPos+1
      moveUsed = false
    end
    
    local function resetPos()
      if currPos == fieldLength then
        droneDest = "farm"
        locate(droneDest)
        local rowStart = destLoc[3]+droneDirZ
        drone.move(0,0,rowStart)
        currPos = 1
        while drone.getVelocity() > 0 do
          rowHarvested = false
        end
      end
      rowHarvested = true
      rowsDone = rowsDone+1
    end
    
    local function nextRow()
        drone.move(droneDirX,0,0)
        rowHarvested = false
    end
    
    local function move()
      drone.move(0,0,droneDirZ)
      moveUsed = true
    end
    
    local function harvest()
      if moveUsed == true then
        if drone.detect(0) == true and currPos > 0 then
          drone.use(0)
          drone.swing(3)
          drone.setLightColor(4251856)
        else
          drone.setLightColor(16711680)
        end
      end
    end
    
    local function harvestRow()
      while currPos < fieldLength do
        if moveUsed == false then
          move()
        end
        if moveUsed == true then
          harvest()
          updatePos()
        end
      end
      resetPos()
      if rowHarvested == true and rowsDone < fieldWidth then
      nextRow()
      end
    end    

    init()
    
    while initialized == true do
      droneDest = "farm"
      locate(droneDest)
      drone.move(destLoc[1],destLoc[2],destLoc[3])
      awaitArrival()
      move()
      updatePos()
      while rowsDone < fieldWidth do
        if rowHarvested == false then
          if drone.getVelocity() <= 0 then
            detection()
            if isDetected == true then
              harvestRow()
            else
              while isDetected == false do
                nextRow()
                rowsDone = rowsDone+1
                drone.setLightColor(16711680)
                detection()
              end
            end
          end
        end
        harvestCompleted()
      end
      resetHarvest()
    end
    
    end