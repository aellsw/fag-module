-- Module Computer Configuration
-- Copy this file and customize for each module

return {
  -- Identity
  module_id = "drain_01",          -- Unique identifier for this module
  factory_id = "test",             -- Which factory this module belongs to
  
  -- Network
  factory_lan_id = 10,             -- Computer ID of the Factory LAN computer
  
  -- Timing
  update_interval = 2,             -- Seconds between data updates (1-5 recommended)
  
  -- Peripherals
  -- The Create peripheral that provides RPM data
  kinetic_peripheral = "Create_RotationSpeedController_0",  -- Reports target speed as RPM
  
  -- Separate peripheral for stress measurement
  stress_peripheral = "Create_Stressometer_0",  -- Stress data
  
  -- Input/output inventories for measuring items per minute
  -- Leave as nil if this module doesn't process items
  input_inventory = nil,           -- e.g. "minecraft:chest_0"
  output_inventory = nil,          -- e.g. "minecraft:chest_1"
  
  -- Depot peripheral for throughput measurement
  depot_peripheral = "create:depot_1",  -- Depot with items passing through
  use_throughput_mode = true,      -- Enable throughput tracking
  
  -- Item measurement
  measure_items = true,            -- Enable item throughput measurement
  item_check_interval = 0.05,      -- Check 20x per second for fast-moving items
  
  -- Control: Use redstone signal for on/off state
  -- (control_peripheral not needed when using redstone)
  redstone_side = "left",          -- ON when high, OFF when low
  
  -- Safety limits
  max_rpm = 256,                   -- Maximum allowed RPM
  overstress_threshold = 0.95,     -- Warn when stress reaches 95% of capacity
  
  -- Logging
  enable_logging = true,           -- Enable debug logging
  log_file = "module.log"          -- Log file path
}
