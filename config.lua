-- Module Computer Configuration
-- Copy this file and customize for each module

return {
  -- Identity
  module_id = "crusher_01",       -- Unique identifier for this module
  factory_id = "iron",             -- Which factory this module belongs to
  
  -- Network
  factory_lan_id = 10,             -- Computer ID of the Factory LAN computer
  
  -- Timing
  update_interval = 2,             -- Seconds between data updates (1-5 recommended)
  
  -- Peripherals
  -- The Create peripheral that provides RPM data
  -- Leave as nil to auto-detect
  kinetic_peripheral = nil,        -- e.g. "Create_RotationSpeedController_0" or "top"
  
  -- Optional: separate peripheral for stress measurement
  -- If your RPM peripheral doesn't have stress data, specify a stressometer here
  stress_peripheral = nil,         -- e.g. "Create_Stressometer_0" or "left"
  
  -- Input/output inventories for measuring items per minute
  -- Leave as nil if this module doesn't process items
  input_inventory = nil,           -- e.g. "minecraft:chest_0"
  output_inventory = nil,          -- e.g. "minecraft:chest_1"
  
  -- Depot peripheral for throughput measurement (e.g., Create Depot / Item Drain)
  -- Use when items pass through quickly and don't accumulate in an inventory
  depot_peripheral = nil,          -- e.g. "createdepot_0" or side like "bottom"
  use_throughput_mode = false,     -- true = measure items that pass through depot/drain
  
  -- Item measurement
  measure_items = true,            -- Set to false if no item measurement needed
  item_check_interval = 1,         -- Seconds between item counts for IPM/throughput calculation
  
  -- Control peripheral (optional)
  -- Used to enable/disable the machine (e.g., clutch, motor)
  control_peripheral = nil,        -- e.g. "Create_Clutch_0" or "Create_Motor_0"
  control_type = "clutch",         -- "clutch", "motor", or "none"
  
  -- Redstone control (optional) — read a redstone input for on/off state
  redstone_side = nil,             -- e.g. "left" = on when high, off when low
  
  -- Safety limits
  max_rpm = 256,                   -- Maximum allowed RPM
  overstress_threshold = 0.95,     -- Warn when stress reaches 95% of capacity
  
  -- Logging
  enable_logging = false,          -- Enable debug logging
  log_file = "module.log"          -- Log file path
}
