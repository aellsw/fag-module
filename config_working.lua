-- Working Module Configuration
-- Based on actual peripheral capabilities:
-- - RotationSpeedController: only has target speed, not actual RPM
-- - Stressometer: has stress data
-- - Item Drain: cannot be monitored (no inventory methods)
-- - Redstone: can read on/off state

return {
  -- Identity
  module_id = "drain_01",
  factory_id = "test",
  
  -- Network
  factory_lan_id = 10,
  
  -- Timing
  update_interval = 2,
  
  -- Peripherals
  -- Speed controller only reports TARGET speed, not actual RPM
  -- We'll read from stressometer only
  kinetic_peripheral = nil,              -- Speed controller doesn't give actual RPM
  stress_peripheral = "Create_Stressometer_0",  -- Has stress data
  
  -- Item measurement
  -- Item drain CANNOT be monitored - it has no inventory methods
  -- To track items, you need a chest BEFORE the drain
  measure_items = false,
  depot_peripheral = nil,
  use_throughput_mode = false,
  output_inventory = nil,                -- Set to chest name if you add one
  item_check_interval = 1,
  
  -- Control
  control_peripheral = nil,
  control_type = "none",
  
  -- Redstone control
  redstone_side = "left",                -- Change based on your setup
  
  -- Safety
  max_rpm = 256,
  overstress_threshold = 0.95,
  
  -- Logging
  enable_logging = true,
  log_file = "module.log"
}
