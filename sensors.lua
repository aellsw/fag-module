-- Module Sensor Reading Utilities
-- Reads data from Create mod peripherals

local sensors = {}

-- Find Create kinetic peripheral (speed controller, motor, etc.)
function sensors.find_kinetic_peripheral(peripheral_name)
  if peripheral_name then
    -- Use specified peripheral
    if peripheral.isPresent(peripheral_name) then
      return peripheral.wrap(peripheral_name)
    else
      return nil, "Specified peripheral not found: " .. peripheral_name
    end
  end
  
  -- Auto-detect Create kinetic peripherals
  local create_types = {
    "Create_RotationSpeedController",
    "Create_Motor",
    "Create_Clutch",
    "Create_Gearshift",
    "Create_Stressometer"
  }
  
  for _, ptype in ipairs(create_types) do
    local p = peripheral.find(ptype)
    if p then
      return p, ptype
    end
  end
  
  return nil, "No Create kinetic peripheral found"
end

-- Read kinetic data (RPM, stress, capacity)
function sensors.read_kinetic_data(kinetic_peripheral)
  if not kinetic_peripheral then
    return nil, "No peripheral provided"
  end
  
  local success, result = pcall(function()
    local data = {
      rpm = 0,
      stress_units = 0,
      stress_capacity = 0
    }
    
    -- Try to get RPM/speed
    if kinetic_peripheral.getSpeed then
      data.rpm = kinetic_peripheral.getSpeed() or 0
    end
    
    -- Try to get stress
    if kinetic_peripheral.getStress then
      data.stress_units = kinetic_peripheral.getStress() or 0
    end
    
    -- Try to get stress capacity
    if kinetic_peripheral.getStressCapacity then
      data.stress_capacity = kinetic_peripheral.getStressCapacity() or 0
    end
    
    return data
  end)
  
  if not success then
    return nil, "Failed to read kinetic data: " .. tostring(result)
  end
  
  return result
end

-- Find inventory peripheral for item counting
function sensors.find_inventory(inventory_name)
  if inventory_name then
    if peripheral.isPresent(inventory_name) then
      return peripheral.wrap(inventory_name)
    else
      return nil, "Specified inventory not found: " .. inventory_name
    end
  end
  
  -- Auto-detect nearby inventories
  local inv = peripheral.find("inventory")
  if inv then
    return inv
  end
  
  return nil, "No inventory peripheral found"
end

-- Count total items in an inventory
function sensors.count_items(inventory)
  if not inventory then
    return 0
  end
  
  local success, result = pcall(function()
    local total = 0
    local size = inventory.size()
    
    for slot = 1, size do
      local item = inventory.getItemDetail(slot)
      if item then
        total = total + item.count
      end
    end
    
    return total
  end)
  
  if not success then
    return 0
  end
  
  return result
end

-- Items per minute calculator
sensors.ipm_calculator = {}

function sensors.create_ipm_calculator()
  local calc = {
    last_count = 0,
    last_time = 0,
    current_ipm = 0,
    samples = {},
    max_samples = 5  -- Average over last 5 samples
  }
  
  function calc:update(current_count)
    local current_time = os.epoch("utc")
    
    -- First measurement
    if self.last_time == 0 then
      self.last_count = current_count
      self.last_time = current_time
      return 0
    end
    
    -- Calculate time elapsed in minutes
    local time_elapsed_ms = current_time - self.last_time
    local time_elapsed_min = time_elapsed_ms / 60000.0
    
    if time_elapsed_min == 0 then
      return self.current_ipm
    end
    
    -- Calculate items moved
    local items_moved = math.abs(current_count - self.last_count)
    
    -- Calculate IPM
    local ipm = items_moved / time_elapsed_min
    
    -- Store sample
    table.insert(self.samples, ipm)
    if #self.samples > self.max_samples then
      table.remove(self.samples, 1)
    end
    
    -- Calculate average
    local sum = 0
    for _, sample in ipairs(self.samples) do
      sum = sum + sample
    end
    self.current_ipm = sum / #self.samples
    
    -- Update for next calculation
    self.last_count = current_count
    self.last_time = current_time
    
    return self.current_ipm
  end
  
  function calc:get_ipm()
    return self.current_ipm
  end
  
  function calc:reset()
    self.last_count = 0
    self.last_time = 0
    self.current_ipm = 0
    self.samples = {}
  end
  
  return calc
end

-- Throughput calculator for depots (items that pass through)
-- Tracks items seen and calculates rate continuously
function sensors.create_throughput_calculator()
  local calc = {
    total_items_seen = 0,
    last_check_time = 0,
    current_ipm = 0,
    samples = {},           -- Store recent item counts with timestamps
    max_sample_age = 60000  -- Keep samples for 60 seconds
  }
  
  function calc:update(depot_peripheral)
    local current_time = os.epoch("utc")
    
    -- Initialize on first call
    if self.last_check_time == 0 then
      self.last_check_time = current_time
      return 0
    end
    
    -- Count items currently on depot
    local items_on_depot = 0
    if depot_peripheral and depot_peripheral.list then
      local items = depot_peripheral.list()
      for _, item in pairs(items) do
        items_on_depot = items_on_depot + item.count
      end
    end
    
    -- Record items seen at this timestamp
    if items_on_depot > 0 then
      table.insert(self.samples, {
        timestamp = current_time,
        count = items_on_depot
      })
      self.total_items_seen = self.total_items_seen + items_on_depot
    end
    
    -- Remove old samples (older than 60 seconds)
    local cutoff_time = current_time - self.max_sample_age
    while #self.samples > 0 and self.samples[1].timestamp < cutoff_time do
      table.remove(self.samples, 1)
    end
    
    -- Calculate IPM from samples in the last 60 seconds
    if #self.samples > 0 then
      local total_items = 0
      local oldest_time = self.samples[1].timestamp
      local time_span_ms = current_time - oldest_time
      
      for _, sample in ipairs(self.samples) do
        total_items = total_items + sample.count
      end
      
      -- Convert to items per minute
      if time_span_ms > 0 then
        self.current_ipm = (total_items / time_span_ms) * 60000
      end
    else
      -- No recent samples, IPM goes to 0
      self.current_ipm = 0
    end
    
    self.last_check_time = current_time
    return self.current_ipm
  end
  
  function calc:get_ipm()
    return self.current_ipm
  end
  
  function calc:get_total()
    return self.total_items_seen
  end
  
  function calc:reset()
    self.total_items_seen = 0
    self.last_check_time = 0
    self.current_ipm = 0
    self.items_this_minute = 0
    self.minute_start = 0
  end
  
  return calc
end

-- Read redstone signal (for on/off control)
function sensors.read_redstone(side)
  if not side then
    return false
  end
  
  local success, result = pcall(function()
    return redstone.getInput(side)
  end)
  
  if not success then
    return false
  end
  
  return result
end

-- Check if machine is enabled (running)
function sensors.is_machine_enabled(kinetic_peripheral)
  if not kinetic_peripheral then
    return false
  end
  
  -- Check if RPM is non-zero
  local success, rpm = pcall(function()
    if kinetic_peripheral.getSpeed then
      return kinetic_peripheral.getSpeed()
    end
    return 0
  end)
  
  if not success then
    return false
  end
  
  return rpm ~= nil and rpm ~= 0
end

-- Get control peripheral for enable/disable
function sensors.find_control_peripheral(control_name, control_type)
  if control_name then
    if peripheral.isPresent(control_name) then
      return peripheral.wrap(control_name), control_type
    end
  end
  
  -- Auto-detect control peripherals
  local types = {
    {type = "Create_Clutch", name = "clutch"},
    {type = "Create_Motor", name = "motor"},
    {type = "Create_Gearshift", name = "gearshift"}
  }
  
  for _, info in ipairs(types) do
    local p = peripheral.find(info.type)
    if p then
      return p, info.name
    end
  end
  
  return nil, "none"
end

-- Enable machine (activate clutch/motor)
function sensors.enable_machine(control_peripheral, control_type)
  if not control_peripheral or control_type == "none" then
    return false, "No control peripheral"
  end
  
  local success, err = pcall(function()
    if control_type == "clutch" then
      -- Clutches use setClutch(true/false)
      if control_peripheral.setClutch then
        control_peripheral.setClutch(true)
      end
    elseif control_type == "motor" then
      -- Motors might have different methods
      -- This is a placeholder - adjust based on actual Create API
      if control_peripheral.setSpeed then
        -- Don't change speed, just ensure it's running
      end
    end
  end)
  
  if not success then
    return false, "Failed to enable: " .. tostring(err)
  end
  
  return true
end

-- Disable machine (deactivate clutch/motor)
function sensors.disable_machine(control_peripheral, control_type)
  if not control_peripheral or control_type == "none" then
    return false, "No control peripheral"
  end
  
  local success, err = pcall(function()
    if control_type == "clutch" then
      if control_peripheral.setClutch then
        control_peripheral.setClutch(false)
      end
    elseif control_type == "motor" then
      if control_peripheral.setSpeed then
        control_peripheral.setSpeed(0)
      end
    end
  end)
  
  if not success then
    return false, "Failed to disable: " .. tostring(err)
  end
  
  return true
end

-- Set machine speed (if supported)
function sensors.set_machine_speed(control_peripheral, control_type, speed)
  if not control_peripheral or control_type == "none" then
    return false, "No control peripheral"
  end
  
  local success, err = pcall(function()
    if control_peripheral.setSpeed then
      control_peripheral.setSpeed(speed)
    elseif control_peripheral.setTargetSpeed then
      control_peripheral.setTargetSpeed(speed)
    else
      error("Speed control not supported")
    end
  end)
  
  if not success then
    return false, "Failed to set speed: " .. tostring(err)
  end
  
  return true
end

-- Check for overstress condition
function sensors.check_overstress(stress_units, stress_capacity, threshold)
  threshold = threshold or 0.95
  
  if stress_capacity == 0 then
    return false
  end
  
  local stress_ratio = stress_units / stress_capacity
  return stress_ratio >= threshold
end

-- Get all peripheral names (for debugging)
function sensors.list_peripherals()
  local peripherals = {}
  local names = peripheral.getNames()
  
  for _, name in ipairs(names) do
    table.insert(peripherals, {
      name = name,
      type = peripheral.getType(name)
    })
  end
  
  return peripherals
end

return sensors
