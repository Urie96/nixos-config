---@class Entry
---@field public expire_at number
---@field public value any

---@class Cache
---@field public entries Entry[]
local cache = {}

cache.new = function()
  local self = setmetatable({}, { __index = cache })
  self.entries = {}
  return self
end

---Get cache value
---@param key string|string[]
---@return any|nil
cache.get = function(self, key)
  key = self:key(key)
  local entry = self.entries[key]
  if entry ~= nil and entry.expire_at > os.time() then
    return self.entries[key].value
  end
  return nil
end

---Set cache value explicitly
---@param key string|string[]
---@vararg any
cache.set = function(self, key, value, expiration)
  key = self:key(key)
  local expire_at = math.huge
  if expiration then
    expire_at = os.time() + expiration
  end
  self.entries[key] = { expire_at = expire_at, value = value }
end

---Ensure value by callback
---@generic T
---@param key string|string[]
---@param callback fun(): T
---@return T
cache.ensure = function(self, key, callback)
  local value = self:get(key)
  if value == nil then
    local v = callback()
    self:set(key, v)
    return v
  end
  return value
end

---Clear all cache entries
cache.clear = function(self)
  self.entries = {}
end

---Create key
---@param key string|string[]
---@return string
cache.key = function(_, key)
  if type(key) == "table" then
    return table.concat(key, ":")
  end
  return key
end

return cache
