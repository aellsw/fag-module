-- Debug script to list all peripherals and their methods
local output = {}

local function log(msg)
  table.insert(output, msg)
  print(msg)
end

log("=== Peripheral Debug ===")
log("")

local names = peripheral.getNames()
log("Found " .. #names .. " peripherals:")
log("")

for _, name in ipairs(names) do
  local ptype = peripheral.getType(name)
  log("Peripheral: " .. name)
  log("  Type: " .. ptype)
  
  local p = peripheral.wrap(name)
  if p then
    log("  Methods:")
    local methods = peripheral.getMethods(name)
    if methods then
      for _, method in ipairs(methods) do
        log("    - " .. method)
      end
    end
    
    -- Try to call common methods
    if p.getSpeed then
      local success, speed = pcall(function() return p.getSpeed() end)
      if success then
        log("  Speed/RPM: " .. tostring(speed))
      end
    end
    
    if p.getStress then
      local success, stress = pcall(function() return p.getStress() end)
      if success then
        log("  Stress: " .. tostring(stress))
      end
    end
    
    if p.getStressCapacity then
      local success, capacity = pcall(function() return p.getStressCapacity() end)
      if success then
        log("  Capacity: " .. tostring(capacity))
      end
    end
    
    if p.size then
      local success, size = pcall(function() return p.size() end)
      if success then
        log("  Inventory Size: " .. tostring(size))
      end
    end
    
    if p.list then
      local success, items = pcall(function() return p.list() end)
      if success and items then
        log("  Items in inventory:")
        for slot, item in pairs(items) do
          log("    Slot " .. slot .. ": " .. item.count .. "x " .. item.name)
        end
      end
    end
  end
  
  log("")
end

-- Check redstone
log("=== Redstone Signals ===")
local sides = {"top", "bottom", "left", "right", "front", "back"}
for _, side in ipairs(sides) do
  local input = redstone.getInput(side)
  log(side .. ": " .. tostring(input))
end

-- Write to file
log("")
log("Writing to peripheral_debug.txt...")
local file = fs.open("peripheral_debug.txt", "w")
for _, line in ipairs(output) do
  file.writeLine(line)
end
file.close()
log("Done! Check peripheral_debug.txt")
