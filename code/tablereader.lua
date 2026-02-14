local f = string.format
local rep = string.rep
local concat = table.concat
local find = table.find or function(t_, element)
  for i, v in ipairs(t_) do
    if v == element then
      return i
    end
  end
end
local insert = table.insert
local tonumber = tonumber
local tostring = tostring
local type = type

local reader

local function read(table_, level)
  if level <= reader.DEFAULT_LEVEL and reader.CAN_TABLES_REPEAT then
    reader.Cycled = {}
  end
  if find(reader.Cycled, table_) then
    return '{Cyclic}'
  end
  reader.Cycled[level] = table_
  
  local stringRepr = {'{', '}'}
  local n = 1
  for k, v in next, table_ do
    local fromType = reader.types[type(v)] or reader.anyType
    local element = reader:f(k, fromType(v, level), level)
    
    n = n+1
    insert(stringRepr, n, element)
  end
  
  return concat(stringRepr, #stringRepr > 2 and reader.SEP..rep(reader.WS, level - 1) or '')
end

reader = {
  WS = '\t',
  SEP = '\n',
  DEFAULT_LEVEL = 1,
  CAN_TABLES_REPEAT = true,
  
  getKoI = function(k)
    return tonumber(k) or tostring(k), tonumber(k) and '[%i] = %s;' or '[%q] = %s;'
  end,
  
  f = function(self, k, v, level)
    local KoI, repr = self.getKoI(k)
    return rep(self.WS, level)..f(repr, KoI, tostring(v))
  end,
  
  types = {
    number = function(v)
      return tonumber(v)
    end,
    string = function(v)
      return f('%q', v)
    end,
    table = function(v, level)
      return read(v, level + 1)
    end
  },
  anyType = tostring,
  
  Cycled = {}
}

function reader:read(table_)
  self.Cycled = {}
  return read(table_, self.DEFAULT_LEVEL)
end

return reader