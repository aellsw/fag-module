-- Module Computer Test Script
-- Tests sensor reading and message building without network

local sensors = require("module.sensors")
local protocol = require("fag.protocol")

print("=== Module Computer Test ===")
print("")

-- Test 1: List all peripherals
print("Test 1: Detecting peripherals...")
local peripherals = sensors.list_peripherals()
if #peripherals == 0 then
  print("  No peripherals found!")
else
  print("  Found " .. #peripherals .. " peripherals:")
  for _, p in ipairs(peripherals) do
    print("    - " .. p.name .. " (" .. p.type .. ")")
  end
end
print("")

-- Test 2: Find Create kinetic peripheral
print("Test 2: Finding Create kinetic peripheral...")
local kinetic, kinetic_type = sensors.find_kinetic_peripheral(nil)
if kinetic then
  print("  SUCCESS: Found " .. kinetic_type)
  
  -- Test 3: Read kinetic data
  print("")
  print("Test 3: Reading kinetic data...")
  local data, err = sensors.read_kinetic_data(kinetic)
  if data then
    print("  RPM: " .. data.rpm)
    print("  Stress: " .. data.stress_units .. " / " .. data.stress_capacity .. " SU")
    if data.stress_capacity > 0 then
      local pct = (data.stress_units / data.stress_capacity) * 100
      print("  Stress %: " .. string.format("%.1f%%", pct))
    end
  else
    print("  ERROR: " .. err)
  end
else
  print("  WARNING: " .. kinetic_type)
  print("  Make sure a Create peripheral is connected!")
end
print("")

-- Test 4: Build a module_data message
print("Test 4: Building module_data message...")
local msg = protocol.build_message(protocol.MSG_TYPES.MODULE_DATA, {
  module_id = "test_module",
  factory_id = "test_factory",
  rpm = 64,
  stress_units = 512,
  stress_capacity = 2048,
  items_per_min = 20.5,
  enabled = true
})

print("  Protocol: " .. msg.protocol)
print("  Type: " .. msg.msg_type)
print("  Timestamp: " .. msg.timestamp)
print("  Module: " .. msg.module_id)
print("")

-- Test 5: Validate message
print("Test 5: Validating message...")
local valid, err = protocol.validate_message(msg)
if valid then
  print("  SUCCESS: Message is valid")
  
  local valid_data, err_data = protocol.validate_module_data(msg)
  if valid_data then
    print("  SUCCESS: module_data fields are valid")
  else
    print("  ERROR: " .. err_data)
  end
else
  print("  ERROR: " .. err)
end
print("")

-- Test 6: Control peripheral detection
print("Test 6: Finding control peripheral...")
local control, ctrl_type = sensors.find_control_peripheral(nil, nil)
if control then
  print("  SUCCESS: Found " .. ctrl_type)
else
  print("  INFO: No control peripheral (this is optional)")
end
print("")

-- Test 7: Inventory detection
print("Test 7: Finding inventory peripheral...")
local inventory, inv_err = sensors.find_inventory(nil)
if inventory then
  print("  SUCCESS: Found inventory")
  
  local item_count = sensors.count_items(inventory)
  print("  Item count: " .. item_count)
else
  print("  INFO: " .. inv_err .. " (this is optional)")
end
print("")

-- Test 8: IPM Calculator
print("Test 8: Testing IPM calculator...")
local ipm_calc = sensors.create_ipm_calculator()
print("  Created IPM calculator")
print("  Initial IPM: " .. ipm_calc:get_ipm())

-- Simulate measurements
ipm_calc:update(0)
sleep(1)
ipm_calc:update(10)
sleep(1)
ipm_calc:update(20)
print("  After 2 measurements: " .. string.format("%.1f", ipm_calc:get_ipm()) .. " IPM")
print("")

-- Test 9: Command ID generation
print("Test 9: Testing command ID generation...")
for i = 1, 3 do
  local cmd_id = protocol.generate_command_id()
  print("  Command " .. i .. ": " .. cmd_id)
end
print("")

print("=== Test Complete ===")
print("")
print("Summary:")
print("  Peripherals: " .. #peripherals .. " found")
print("  Kinetic: " .. (kinetic and "OK" or "NOT FOUND"))
print("  Protocol: OK")
print("  Messages: OK")
print("")
print("Ready to run module/main.lua!")
