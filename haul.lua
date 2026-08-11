-- =========================================================
-- CC: Tweaked - Exact Route Automated Item Hauler (haul.lua)
-- Setup:
--   Place Turtle at Base Origin (510, 122) facing forward into tunnel.
--   Behind Turtle: Functional Storage Controller
--   In Front of Turtle: Overflow Storage Chest
-- Exact Route:
--   1. Turn Left (Facing 3)
--   2. Move Forward 67 blocks (X: 510 -> 577)
--   3. Move Down 10 blocks (Y: 122 -> 112)
--   4. Turn Right (Facing 0 / Facing Miner Chest)
--   5. Pull items from Miner Chest
--   6. Move Up 10 blocks (Y: 112 -> 122)
--   7. Turn 180 degrees & Move Forward 67 blocks (X: 577 -> 510)
--   8. Turn 180 degrees (Align facing 0 at Base)
--   9. Turn 180 degrees -> Offload to Storage Controller (Behind)
--  10. Turn 180 degrees -> Offload leftovers to Overflow Chest (Front)
-- =========================================================

-- Coordinate & Direction State Tracking
local pos = { x = 510, y = 122, z = 0, facing = 0 }

-----------------------------------------------------------
-- Movement & Fuel Functions
-----------------------------------------------------------
local function turnRight()
    turtle.turnRight()
    pos.facing = (pos.facing + 1) % 4
end

local function turnLeft()
    turtle.turnLeft()
    pos.facing = (pos.facing + 3) % 4
end

local function checkFuel()
    if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < 150 then
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then
                turtle.refuel()
            end
        end
        turtle.select(1)
    end
end

local function safeDig()
    local attempts = 0
    while turtle.detect() and attempts < 10 do
        turtle.dig()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function safeDigUp()
    local attempts = 0
    while turtle.detectUp() and attempts < 10 do
        turtle.digUp()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function safeDigDown()
    local attempts = 0
    while turtle.detectDown() and attempts < 10 do
        turtle.digDown()
        attempts = attempts + 1
        sleep(0.3)
    end
end

local function moveForward()
    checkFuel()
    safeDig()
    while not turtle.forward() do
        safeDig()
        turtle.attack()
        sleep(0.4)
    end
    if pos.facing == 0 then pos.z = pos.z + 1
    elseif pos.facing == 1 then pos.x = pos.x + 1
    elseif pos.facing == 2 then pos.z = pos.z - 1
    elseif pos.facing == 3 then pos.x = pos.x - 1 end
end

local function moveDown()
    checkFuel()
    safeDigDown()
    while not turtle.down() do
        safeDigDown()
        turtle.attackDown()
        sleep(0.4)
    end
    pos.y = pos.y - 1
end

local function moveUp()
    checkFuel()
    safeDigUp()
    while not turtle.up() do
        safeDigUp()
        turtle.attackUp()
        sleep(0.4)
    end
    pos.y = pos.y + 1
end

-----------------------------------------------------------
-- Route Execution Functions
-----------------------------------------------------------
local function runOutbound()
    print("[Outbound] Navigating to Miner Chest...")
    
    -- Turn Left at start (Facing 3)
    turnLeft()
    
    -- Move forward 67 blocks (X: 510 -> 577)
    for i = 1, 67 do
        moveForward()
    end
    
    -- Move down 10 blocks (Y: 122 -> 112)
    for i = 1, 10 do
        moveDown()
    end
    
    -- Turn Right to face Miner Chest (Facing 0)
    turnRight()
end

local function pullFromMinerChest()
    local pulled = false
    print("[Miner Chest] Collecting items...")
    for slot = 1, 16 do
        turtle.select(slot)
        while turtle.suck() do
            pulled = true
            if turtle.getItemCount(slot) == turtle.getItemSpace(slot) then
                break
            end
        end
    end
    turtle.select(1)
    return pulled
end

local function runInbound()
    print("[Inbound] Returning to Base Storage...")
    
    -- Move up 10 blocks (Y: 112 -> 122)
    for i = 1, 10 do
        moveUp()
    end
    
    -- Turn 180 degrees to face back towards X=510 (Facing 2)
    turnRight()
    turnRight()
    
    -- Move forward 67 blocks back to X=510
    for i = 1, 67 do
        moveForward()
    end
    
    -- Turn 180 degrees to realign to original Base facing (Facing 0)
    turnRight()
    turnRight()
end

local function offloadAtBase()
    print("[Offloading] Depositing items at Base...")
    
    -- Turn 180 degrees to face Storage Controller behind turtle (Facing 2)
    turnRight()
    turnRight()
    
    -- Attempt offload into Functional Storage Controller
    local remainingItems = false
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            turtle.drop() -- Storage Controller accepts matching drawer items
            if turtle.getItemCount(slot) > 0 then
                remainingItems = true
            end
        end
    end
    
    -- Turn 180 degrees back to face Overflow Chest in front (Facing 0)
    turnRight()
    turnRight()
    
    -- Offload any unhandled or leftover items into Overflow Chest
    if remainingItems then
        print("[Overflow] Offloading unhandled items into Overflow Chest...")
        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.getItemCount(slot) > 0 then
                turtle.drop() -- Drops into Overflow Chest in front
            end
        end
    end
    
    turtle.select(1)
end

-----------------------------------------------------------
-- Main Loop Execution
-----------------------------------------------------------
print("========================================")
print(" Exact Route Automated Hauler Active")
print(" Base: (510, 122) | Target: (577, 112)")
print(" Behind: Storage Controller | Front: Overflow Chest")
print("========================================")

while true do
    runOutbound()
    
    local itemsCollected = pullFromMinerChest()
    
    runInbound()
    
    offloadAtBase()
    
    if itemsCollected then
        print("[Status] Cycle complete. Resuming immediately...")
    else
        print("[Status] Miner Chest empty. Standing by at Base for 10s...")
        sleep(10)
    end
end
