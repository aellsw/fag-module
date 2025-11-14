# Module Computer (Tier 1) - Setup Guide

The Module Computer controls individual Create machines and sends sensor data to the Factory LAN.

## Files

- **`config.lua`** - Configuration (customize for each module)
- **`sensors.lua`** - Sensor reading utilities
- **`main.lua`** - Main program
- **`test.lua`** - Test script (run before main program)

## Hardware Setup

### Required:
1. **ComputerCraft Computer** (any tier)
2. **Wired or Wireless Modem**
3. **Create Kinetic Peripheral** (Speed Controller, Motor, Clutch, etc.)

### Optional:
- **Control Peripheral** (Clutch/Motor for enable/disable)
- **Output Chest** (for measuring items per minute)

### Example Setup:
```
[Computer]
    |
[Modem] -----> [Factory LAN Computer]
    |
[Create Speed Controller] -----> [Your Create Machine]
    |
[Output Chest] -----> (items flow here)
```

## Installation Steps

### 1. Copy Files to Computer

In Minecraft, on your ComputerCraft computer:

```lua
-- Create directories
mkdir fag
mkdir module

-- Copy files (use pastebin, wget, or disk drive)
-- You need:
--   fag/protocol.lua
--   fag/network.lua
--   module/config.lua
--   module/sensors.lua
--   module/main.lua
--   module/test.lua
```

### 2. Configure the Module

Edit `module/config.lua`:

```lua
edit module/config.lua
```

**Important settings:**
- `module_id` - Unique name (e.g., "crusher_01", "fan_01")
- `factory_id` - Which factory (e.g., "iron", "steel")
- `factory_lan_id` - Computer ID of Factory LAN (run `id` on that computer)
- `update_interval` - How often to send data (2 seconds recommended)

**Example:**
```lua
return {
  module_id = "crusher_01",
  factory_id = "iron",
  factory_lan_id = 10,  -- Change to your Factory LAN's ID
  update_interval = 2,
  -- ... other settings
}
```

### 3. Test the Setup

Run the test script first:

```lua
module/test.lua
```

This will:
- ✓ Detect all peripherals
- ✓ Find Create kinetic peripheral
- ✓ Read RPM and stress data
- ✓ Test message building
- ✓ Verify everything works

**Expected output:**
```
=== Module Computer Test ===

Test 1: Detecting peripherals...
  Found 3 peripherals:
    - Create_RotationSpeedController_0 (Create_RotationSpeedController)
    - modem_0 (modem)
    - minecraft:chest_1 (inventory)

Test 2: Finding Create kinetic peripheral...
  SUCCESS: Found Create_RotationSpeedController

Test 3: Reading kinetic data...
  RPM: 64.0
  Stress: 512 / 2048 SU
  Stress %: 25.0%

[... more tests ...]

=== Test Complete ===
Ready to run module/main.lua!
```

### 4. Run the Module Computer

```lua
module/main.lua
```

**What you'll see:**
```
=== Module Computer ===
Module: crusher_01
Factory: iron
Computer ID: 5

Status: ENABLED
RPM: 64.0
Stress: 512 / 2048 SU
Stress: 25.0%
Items/min: 20.5

Network: OK
Factory LAN: 10

Press Ctrl+T to stop
```

The computer will:
- Read sensors every 2 seconds
- Send data to Factory LAN
- Listen for commands
- Update display continuously

## Troubleshooting

### "No Create peripheral found"

**Problem:** Can't find Create machine

**Solutions:**
1. Place a Create Speed Controller next to the computer
2. Or connect via wired modem network
3. Or specify peripheral name in `config.lua`:
   ```lua
   kinetic_peripheral = "Create_RotationSpeedController_0"
   ```

### "No modem found"

**Problem:** Can't initialize network

**Solutions:**
1. Attach a modem to the computer (any side)
2. For wireless: use Wireless Modem (not Wired Modem)
3. For wired: connect with Networking Cable to Factory LAN

### "ERROR sending data"

**Problem:** Can't reach Factory LAN

**Solutions:**
1. Verify Factory LAN is running
2. Check `factory_lan_id` in config matches actual ID
3. For wireless: check range (64 blocks max)
4. For wired: check cables are connected

### Data shows all zeros

**Problem:** Create machine not running or peripheral disconnected

**Solutions:**
1. Make sure Create machine is powered (spinning)
2. Check Create network has power source
3. Verify peripheral is still connected

## Testing Without Factory LAN

You can run the module computer before Factory LAN is ready:

1. Messages will fail to send (that's OK)
2. Display still shows sensor data
3. Verify RPM, stress, and IPM are correct
4. Once Factory LAN starts, messages will go through

## Command Testing

To test command handling, you'll need Factory LAN or a test script that sends `module_command` messages.

### Manual Command Test

Create a test script on another computer:

```lua
local protocol = require("fag.protocol")
local network = require("fag.network")

network.init()

local cmd = protocol.build_message("module_command", {
  command_id = "test_1",
  target_module = "crusher_01",
  action = "disable",
  source = "manual_test",
  priority = "normal"
})

network.send(5, cmd)  -- Send to module computer (ID 5)
print("Command sent!")
```

## Features

### Automatic Features:
- ✓ Auto-detects Create peripherals
- ✓ Measures RPM and stress
- ✓ Calculates items per minute
- ✓ Sends heartbeat every 30 seconds
- ✓ Handles duplicate commands
- ✓ Overstress warnings

### Supported Commands:
- `enable` - Turn on machine
- `disable` - Turn off machine
- `set_speed` - Change RPM
- `restart` - Restart machine
- `emergency_stop` - Immediate shutdown

### Status Display:
- Real-time RPM
- Stress units and percentage
- Items per minute
- Enabled/disabled status
- Network status

## Next Steps

Once the module computer is working:

1. **Add more modules** - Copy config, change module_id
2. **Set up Factory LAN** - Aggregates all module data
3. **Set up SCADA** - Global monitoring and control

## Advanced Configuration

### Multiple Create Machines

To control multiple machines, run one module computer per machine with different `module_id` values:

- `crusher_01`, `crusher_02`, `crusher_03`, etc.
- `fan_01`, `fan_02`, etc.
- `press_01`, `mixer_01`, etc.

### Items Per Minute Accuracy

For best IPM accuracy:
1. Use output chest that receives items
2. Set `item_check_interval = 1` (check every second)
3. Let it run for 30+ seconds to stabilize

### Logging

Enable logging to troubleshoot issues:

```lua
enable_logging = true,
log_file = "crusher_01.log"
```

View log:
```lua
edit crusher_01.log
```

## Support

See `FAG Documentation.txt` for complete protocol specification.
