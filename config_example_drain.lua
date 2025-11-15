-- Module Computer Configuration - Item Drain Example
-- This example shows how to configure a module with:
--   - Stressometer for stress measurement
--   - Speed Controller/Speedometer for RPM
--   - Depot for item throughput (items that pass through quickly)
--   - Redstone signal for on/off control

return {
  -- Identity
  module_id = "drain_01",          -- Unique identifier for this module
  factory_id = "test",              -- Which factory this module belongs to
  
  -- Network
  factory_lan_id = 10,              -- Computer ID of the Factory LAN computer
  
  -- Timing
  update_interval = 2,              -- Seconds between data updates (1-5 recommended)
  
  -- Peripherals
  -- The Create peripheral that provides RPM data
  kinetic_peripheral = "top",       -- Speed controller/speedometer (has RPM)
  
  -- Separate peripheral for stress measurement (stressometer)
  stress_peripheral = "left",       -- Stressometer (has stress data)
  
  -- Depot peripheral for throughput measurement (items pass through)
  depot_peripheral = "createdepot_0",  -- Or use side like "bottom"
  use_throughput_mode = true,       -- Enable throughput tracking (not inventory)
  
  -- Item measurement
  measure_items = true,             -- Enable item throughput measurement
  item_check_interval = 1,          -- Check depot every second
  
  -- Control peripheral (optional - not needed if using redstone)
  control_peripheral = nil,         -- Not needed with redstone control
  control_type = "none",            -- Using redstone instead
  
  -- Redstone control - read input for on/off state
  redstone_side = "left",           -- ON when high, OFF when low
  
  -- Safety limits
  max_rpm = 256,                    -- Maximum allowed RPM
  overstress_threshold = 0.95,      -- Warn when stress reaches 95% of capacity
  
  -- Logging
  enable_logging = false,           -- Enable debug logging
  log_file = "module.log"           -- Log file path
}
