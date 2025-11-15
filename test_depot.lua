-- Test depot peripheral
local depot = peripheral.wrap("create:depot_1")

if not depot then
  print("ERROR: Could not find create:depot_1")
  return
end

print("=== Depot Methods ===")
local methods = peripheral.getMethods("create:depot_1")
for _, method in ipairs(methods) do
  print("  " .. method)
end

print("")
print("=== Testing Methods ===")

if depot.size then
  print("size(): " .. tostring(depot.size()))
end

if depot.list then
  print("list():")
  local items = depot.list()
  if items then
    for slot, item in pairs(items) do
      print("  Slot " .. slot .. ": " .. item.count .. "x " .. item.name)
    end
  else
    print("  (empty or nil)")
  end
end

if depot.getItemDetail then
  print("getItemDetail(1):")
  local item = depot.getItemDetail(1)
  if item then
    print("  " .. item.count .. "x " .. item.name)
  else
    print("  (empty)")
  end
end
