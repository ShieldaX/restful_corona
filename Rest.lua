-- Rest.lua
-- @version 0.1.2
-- ================

-- Require External Library
local class = require 'middleclass'
local json = require "json"
local socket_url = require "socket.url"

-- Class
Rest = class 'Rest'

-- supported http methods
Rest.methods = {
  GET = "GET",
  HEAD = "HEAD",
  PUT = "PUT",
  POST = "POST",
  DELETE = "DELETE",
}

-- Function

local url_escape = socket_url.escape

-- @param r Response table
function Rest.defaultRestHandler(r)
  print("--------------- "..r.name)
  if r.error then
    print("ERROR")
    print("URL: "..r.url)
  else
    print(inspect(r.data))
  end
end

-- Create customized handler
-- @param t [table] List of function beings to handle various situation.
-- @return [function] Handler to handle RESTful response
function Rest.createRestHandler(t)
  return function(r)
    if r.error then
      if t and t.error then
        t.error(r)
      else
        print("--------------- "..r.name)
        print("ERROR")
      end
    else
      if t and type(t.success) == 'function' then
        t.success(r)
      else
        print("--------------- "..r.name)
        print(inspect(r.data))
      end
    end
  end
end

-- Constructor
-- @param obj Target API Object.
-- @param name [string] Name of the API, reference to api description
function Rest:initialize(obj, name)

  -- Save the api description
  if name:find(".json") then
    local inp = assert(io.open(name, "rb"))
    local data = inp:read("*all")
    self.api = json.decode(data)
    print("load api description from JSON file")
  else
    self.api = require('api_'..name)
    print("load api description from Lua Table directly")
  end

  -- For each method
  if self.api.methods then
    for name, t in pairs(self.api.methods) do

      -- Create a function for the object, obj:method(...)
      obj[name] = function(self, ...)
        self:callMethod(name, t, ...) -- function must be implemented correctly
      end
    end
  end

end

-- Parse api description and execute request.
-- @param name [string] API name
-- @oaram t [table] Detail of this api (description)
-- @param headers [table] Request headers
-- @param extraArgList [table] Hash of extra arguments
-- @param preCallbackHook [function] API level callback function
function Rest:call(name, t, headers, extraArgList, preCallbackHook, ...)
  local arg = {n=select('#', ...), ...}
  local index = 1
  local argList = {}
  local callback = nil
  local body = nil

  -- Copy in any extra args
  if extraArgList then --if type(extraArgList) == 'table' then
    for k,v in pairs(extraArgList) do
      argList[k] = v
    end
  end

  -- For each required argument
  if t.required_params then
    for _,a in ipairs(t.required_params) do
      argList[a] = arg[index] -- convert array to hash, combine array of name and array of value, {'a', 'b', 'c'} & {1, 2, 3}
      index = index + 1
    end
  end

  -- Handle optional parameters
  if t.optional_params then
    local optList = arg[index] -- the hash of optional params should be placed after required params
    index = index + 1
    if optList then
      for _,a in ipairs(t.optional_params) do
        argList[a] = optList[a]
      end
    end
  end

  -- Handle payload parameter
  if t.required_payload then
    body = arg[index]
    index = index + 1
  end

  -- Handle callback if necessary
  if arg[index] and type(arg[index]) == "function" then
    callback = arg[index]
  elseif arg[index] and type(arg[index]) == "table" then
    callback = Rest.createRestHandler(arg[index])
  else
    callback = Rest.defaultRestHandler
  end

  -- Handle args and path/arg substitution, /path/:arg?param=escaped_value
  local args = ""
  local newpath = t.path
  for a,v in pairs(argList) do
    -- Try to substitue into path
    newpath, count = newpath:gsub(":"..a, v)
    if count == 0 then
      if args == "" then
        args = "?"..a.."="..url_escape(v)
      else
        args = args .."&".. a .."="..url_escape(v)
      end
    end
  end

  --TODO: handle multitype body, such as binary, multipart formdata or text
  -- body = Rest.handleBody(body)
  -- Encode the body if we can
  if body then
    local ok, newbody = pcall(function() return json.encode(body) end)
    if ok then
      body = newbody
    end
  end

  --Assemble and execute the request
  local url = self.api.base_url .. "/" .. newpath .. args
  local params = {
    headers = headers,
    body = body,
  }

  -- Add event handlers
  local function handleResponse(error, response)
    response.name = name
    response.url = url
    response.method = t.method
    response.error = error -- this means networking error but not http error(404)
    if response.data then
      local ok, msg = pcall(function() return json.decode(response.data) end)
      if ok then
        response.data = msg
      end
    else
      response.data = {}
    end

    if type(preCallbackHook) == 'function' then preCallbackHook(response) end
    if type(callback) == 'function' then callback(response) end
  end

  -- middle event handler
  local function listener(event)
    -- preprocess rest response
    local response = {
      phase = event.phase,
      data = event.response,
      status = event.status,
      requestId = event.requestId,
      responseHeaders = event.responseHeaders
      -- ...
    }

    handleResponse(event.isError, response)
  end

  network.request(url, self.methods[t.method], listener, params)
end

