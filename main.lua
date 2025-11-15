-- Module Computer Main Program
-- Tier 1: Reads Create machines, sends data upward, executes commands

-- Load dependencies
local protocol = require("fag.protocol")
local network = require("fag.network")
local sensors = require("sensors")
local config = require("config")

-- Module state
local state = {
  running = true,
  kinetic_peripheral = nil,
  kinetic_type = nil,
  stress_peripheral = nil,
  control_peripheral = nil,
  control_type = nil,
  output_inventory = nil,
  depot_peripheral = nil,
  ipm_calculator = nil,
  throughput_calculator = nil,
  last_data_send = 0,
  last_item_check = 0,
  enabled = false,
  redstone_enabled = false,
  startup_time = os.epoch("utc")
}

-- Command tracking
local pending_commands = {}
local executed_commands = {}  -- For duplicate detection

-- Logging
local function log(message)
  if config.enable_logging then
    local timestamp = os.date("%H:%M:%S")
    local log_msg = "[" .. timestamp .. "] " .. message
    
    if config.log_file then
      local file = fs.open(config.log_file, "a")
      file.writeLine(log_msg)
      file.close()
    end
    
    print(log_msg)
  else
    print(message)
  end
end

-- Initialize peripherals
local function init_peripherals()
  log("Initializing peripherals...")
  
  -- Find kinetic peripheral
  local kinetic, err = sensors.find_kinetic_peripheral(config.kinetic_peripheral)
  if not kinetic then
    log("ERROR: " .. err)
    log("Available peripherals:")
    for _, p in ipairs(sensors.list_peripherals()) do
      log("  " .. p.name .. " (" .. p.type .. ")")
    end
    return false
  end
  
  state.kinetic_peripheral = kinetic
  state.kinetic_type = err  -- Second return is peripheral type
  log("Found kinetic peripheral: " .. (state.kinetic_type or "unknown"))
  
  -- Find separate stress peripheral if specified
  if config.stress_peripheral then
    if peripheral.isPresent(config.stress_peripheral) then
      state.stress_peripheral = peripheral.wrap(config.stress_peripheral)
      log("Found stress peripheral: " .. config.stress_peripheral)
    else
      log("WARNING: Stress peripheral not found: " .. config.stress_peripheral)
    end
  end
  
  -- Find control peripheral (optional)
  local control, ctrl_type = sensors.find_control_peripheral(
    config.control_peripheral, 
    config.control_type
  )
  state.control_peripheral = control
  state.control_type = ctrl_type
  
  if control then
    log("Found control peripheral: " .. ctrl_type)
  else
    log("No control peripheral (read-only mode)")
  end
  
  -- Find output inventory for IPM (optional)
  if config.measure_items then
    if config.use_throughput_mode and config.depot_peripheral then
      -- Depot/drain mode: measure items passing through
      if peripheral.isPresent(config.depot_peripheral) then
        state.depot_peripheral = peripheral.wrap(config.depot_peripheral)
        state.throughput_calculator = sensors.create_throughput_calculator()
        log("Found depot peripheral for throughput measurement")
      else
        log("WARNING: Depot peripheral not found: " .. config.depot_peripheral)
        log("Throughput measurement disabled")
      end
    elseif config.output_inventory then
      -- Normal inventory mode
      local inv, err = sensors.find_inventory(config.output_inventory)
      if inv then
        state.output_inventory = inv
        state.ipm_calculator = sensors.create_ipm_calculator()
        log("Found output inventory for IPM measurement")
      else
        log("WARNING: " .. err)
        log("IPM measurement disabled")
      end
    end
  end
  
  return true
end

-- Read sensor data
local function read_sensors()
  -- Read kinetic data
  local kinetic_data, err = sensors.read_kinetic_data(state.kinetic_peripheral)
  if not kinetic_data then
    log("ERROR reading sensors: " .. err)
    return {
      rpm = 0,
      stress_units = 0,
      stress_capacity = 0,
      items_per_min = 0,
      enabled = false
    }
  end
  
  -- If we have a separate stress peripheral, read stress from it
  if state.stress_peripheral then
    if state.stress_peripheral.getStress then
      kinetic_data.stress_units = state.stress_peripheral.getStress() or 0
    end
    if state.stress_peripheral.getStressCapacity then
      kinetic_data.stress_capacity = state.stress_peripheral.getStressCapacity() or 0
    end
  end
  
  -- Check if machine is enabled
  -- Check based on control type
  if config.control_type == "redstone" then
    -- Using redstone for status (config.control_peripheral = side name)
    local side = config.redstone_side or config.control_peripheral
    state.enabled = sensors.read_redstone(side)
  elseif state.control_peripheral then
    -- Using kinetic peripheral (clutch/motor)
    state.enabled = sensors.is_machine_enabled(state.control_peripheral)
  else
    -- Fallback: check RPM peripheral
    state.enabled = sensors.is_machine_enabled(state.kinetic_peripheral)
  end
  kinetic_data.enabled = state.enabled
  
  -- Calculate items per minute
  kinetic_data.items_per_min = 0
  
  if config.measure_items then
    local current_time = os.epoch("utc")
    local time_since_check = (current_time - state.last_item_check) / 1000.0
    
    if config.use_throughput_mode and state.throughput_calculator and state.depot_peripheral then
      -- Throughput mode: check every cycle (items pass through quickly)
      if time_since_check >= 0.1 then  -- Check at least 10x per second
        kinetic_data.items_per_min = state.throughput_calculator:update(state.depot_peripheral)
        state.last_item_check = current_time
      else
        kinetic_data.items_per_min = state.throughput_calculator:get_ipm()
      end
    elseif state.ipm_calculator and state.output_inventory then
      -- Normal inventory mode
      if time_since_check >= config.item_check_interval then
        local item_count = sensors.count_items(state.output_inventory)
        kinetic_data.items_per_min = state.ipm_calculator:update(item_count)
        state.last_item_check = current_time
      else
        kinetic_data.items_per_min = state.ipm_calculator:get_ipm()
      end
    end
  end
  
  -- Check for overstress
  if sensors.check_overstress(
    kinetic_data.stress_units, 
    kinetic_data.stress_capacity, 
    config.overstress_threshold
  ) then
    log("WARNING: Approaching overstress!")
  end
  
  return kinetic_data
end

-- Send module_data message
local function send_module_data()
  local sensor_data = read_sensors()
  
  local msg = protocol.build_message(protocol.MSG_TYPES.MODULE_DATA, {
    module_id = config.module_id,
    factory_id = config.factory_id,
    rpm = sensor_data.rpm,
    stress_units = sensor_data.stress_units,
    stress_capacity = sensor_data.stress_capacity,
    items_per_min = sensor_data.items_per_min,
    enabled = sensor_data.enabled
  })
  
  local success, err = network.send(config.factory_lan_id, msg)
  if not success then
    log("ERROR sending data: " .. err)
  end
  
  state.last_data_send = os.epoch("utc")
end

-- Check if command was already executed (duplicate detection)
local function is_duplicate_command(cmd_id)
  if executed_commands[cmd_id] then
    return true
  end
  
  -- Add to executed list
  executed_commands[cmd_id] = os.epoch("utc")
  
  -- Clean old entries (older than 60 seconds)
  for old_id, timestamp in pairs(executed_commands) do
    if os.epoch("utc") - timestamp > 60000 then
      executed_commands[old_id] = nil
    end
  end
  
  return false
end

-- Execute a command
local function execute_command(command_msg)
  local cmd_id = command_msg.command_id
  local action = command_msg.action
  local params = command_msg.parameters or {}
  
  log("Executing command: " .. action .. " (ID: " .. cmd_id .. ")")
  
  -- Check for duplicate
  if is_duplicate_command(cmd_id) then
    log("Duplicate command detected, sending ACK")
    local ack = protocol.build_message(protocol.MSG_TYPES.MODULE_ACK, {
      module_id = config.module_id,
      command_id = cmd_id,
      success = true,
      new_state = state.enabled and "enabled" or "disabled"
    })
    network.send(config.factory_lan_id, ack)
    return
  end
  
  -- Execute action
  local success = false
  local new_state = "unknown"
  local error_reason = nil
  
  if action == protocol.ACTIONS.ENABLE then
    if state.control_peripheral then
      success, error_reason = sensors.enable_machine(
        state.control_peripheral, 
        state.control_type
      )
      new_state = "enabled"
    else
      error_reason = "No control peripheral available"
    end
    
  elseif action == protocol.ACTIONS.DISABLE then
    if state.control_peripheral then
      success, error_reason = sensors.disable_machine(
        state.control_peripheral, 
        state.control_type
      )
      new_state = "disabled"
    else
      error_reason = "No control peripheral available"
    end
    
  elseif action == protocol.ACTIONS.SET_SPEED then
    local speed = params.speed
    if not speed then
      error_reason = "Missing speed parameter"
    elseif speed > config.max_rpm then
      error_reason = "Speed exceeds max_rpm limit"
    elseif state.control_peripheral then
      success, error_reason = sensors.set_machine_speed(
        state.control_peripheral,
        state.control_type,
        speed
      )
      new_state = "speed_" .. speed
    else
      error_reason = "No control peripheral available"
    end
    
  elseif action == protocol.ACTIONS.RESTART then
    if state.control_peripheral then
      -- Disable then enable
      local dis_success = sensors.disable_machine(
        state.control_peripheral, 
        state.control_type
      )
      sleep(0.5)
      success, error_reason = sensors.enable_machine(
        state.control_peripheral,
        state.control_type
      )
      new_state = "restarted"
    else
      error_reason = "No control peripheral available"
    end
    
  else
    error_reason = "Unknown action: " .. action
  end
  
  -- Send acknowledgment or negative acknowledgment
  if success then
    local ack = protocol.build_message(protocol.MSG_TYPES.MODULE_ACK, {
      module_id = config.module_id,
      command_id = cmd_id,
      success = true,
      new_state = new_state
    })
    network.send(config.factory_lan_id, ack)
    log("Command executed successfully")
  else
    local nack = protocol.build_message(protocol.MSG_TYPES.MODULE_NACK, {
      module_id = config.module_id,
      command_id = cmd_id,
      reason = error_reason,
      current_state = state.enabled and "enabled" or "disabled"
    })
    network.send(config.factory_lan_id, nack)
    log("Command failed: " .. error_reason)
  end
end

-- Handle incoming messages
local function handle_message(msg, sender_id)
  -- Update network registry
  network.update_last_seen(sender_id)
  
  -- Route by message type
  if msg.msg_type == protocol.MSG_TYPES.MODULE_COMMAND then
    -- Check if this command is for us
    if msg.target_module == config.module_id then
      -- Handle based on priority
      if msg.priority == protocol.PRIORITY.EMERGENCY then
        log("EMERGENCY command received!")
        execute_command(msg)
      else
        -- Normal priority, execute immediately
        execute_command(msg)
      end
    end
    
  elseif msg.msg_type == protocol.MSG_TYPES.EMERGENCY_STOP then
    log("EMERGENCY STOP received!")
    -- Immediate shutdown
    if state.control_peripheral then
      sensors.disable_machine(state.control_peripheral, state.control_type)
    end
    state.enabled = false
    state.running = false
    
  elseif msg.msg_type == protocol.MSG_TYPES.HEARTBEAT then
    -- Ignore heartbeats for now
    
  else
    log("Received unexpected message type: " .. msg.msg_type)
  end
end

-- Send heartbeat
local function send_heartbeat()
  local msg = protocol.build_message(protocol.MSG_TYPES.HEARTBEAT, {
    sender_id = os.getComputerID(),
    sender_type = "module",
    module_id = config.module_id,
    factory_id = config.factory_id,
    uptime = os.epoch("utc") - state.startup_time,
    status = "operational"
  })
  
  network.broadcast(msg)
end

-- Display status on screen
local function display_status()
  term.clear()
  term.setCursorPos(1, 1)
  
  print("=== Module Computer ===")
  print("Module: " .. config.module_id)
  print("Factory: " .. config.factory_id)
  print("Computer ID: " .. os.getComputerID())
  print("")
  
  local sensor_data = read_sensors()
  
  local status_str = state.enabled and "ENABLED" or "DISABLED"
  if config.redstone_side then
    status_str = status_str .. " (RS:" .. config.redstone_side .. ")"
  end
  print("Status: " .. status_str)
  
  print("RPM: " .. string.format("%.1f", sensor_data.rpm))
  print("Stress: " .. sensor_data.stress_units .. " / " .. sensor_data.stress_capacity .. " SU")
  
  if sensor_data.stress_capacity > 0 then
    local stress_pct = (sensor_data.stress_units / sensor_data.stress_capacity) * 100
    print("Stress: " .. string.format("%.1f%%", stress_pct))
  end
  
  local items_mode = ""
  if config.use_throughput_mode then
    items_mode = " (Throughput)"
  end
  print("Items/min: " .. string.format("%.1f", sensor_data.items_per_min) .. items_mode)
  print("")
  print("Network: " .. (network.is_initialized and "OK" or "ERROR"))
  print("Factory LAN: " .. config.factory_lan_id)
  print("")
  print("Press Ctrl+T to stop")
end

-- Main program
local function main()
  print("=== Module Computer Starting ===")
  print("Module: " .. config.module_id)
  print("Factory: " .. config.factory_id)
  print("")
  
  -- Initialize network
  log("Initializing network...")
  local success, err = network.init()
  if not success then
    log("FATAL: Failed to initialize network: " .. err)
    return
  end
  log("Network initialized on " .. network.modem_side)
  
  -- Enable logging if configured
  if config.enable_logging then
    network.enable_logging(config.log_file)
  end
  
  -- Initialize peripherals
  if not init_peripherals() then
    log("FATAL: Failed to initialize peripherals")
    log("Cannot continue without kinetic peripheral")
    return
  end
  
  -- Send initial heartbeat
  send_heartbeat()
  log("Startup complete")
  
  -- Main loop
  local heartbeat_timer = os.startTimer(30)  -- Heartbeat every 30 seconds
  local display_timer = os.startTimer(1)     -- Update display every second
  
  local last_heartbeat = os.epoch("utc")
  local last_display = os.epoch("utc")
  
  while state.running do
    local current_time = os.epoch("utc")
    
    -- Check if time to send data
    local time_since_send = (current_time - state.last_data_send) / 1000.0
    if time_since_send >= config.update_interval then
      send_module_data()
    end
    
    -- Check for incoming messages (non-blocking)
    local msg, sender_id = network.receive_nonblocking()
    if msg then
      handle_message(msg, sender_id)
    end
    
    -- Update display every second
    if (current_time - last_display) >= 1000 then
      display_status()
      last_display = current_time
    end
    
    -- Send heartbeat every 30 seconds
    if (current_time - last_heartbeat) >= 30000 then
      send_heartbeat()
      last_heartbeat = current_time
    end
    
    sleep(0.05)  -- Small delay to prevent busy-wait
  end
  
  log("Module computer shutting down")
  term.clear()
  term.setCursorPos(1, 1)
  print("Module computer stopped")
end

-- Run main program with error handling
local success, err = pcall(main)
if not success then
  term.clear()
  term.setCursorPos(1, 1)
  print("ERROR: " .. tostring(err))
  print("")
  print("Check log file: " .. config.log_file)
end
