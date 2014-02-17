-----------------------------------------------------------------------------------------
-- Kinvey Class
-----------------------------------------------------------------------------------------
Kinvey = class 'Kinvey'
local b64enc = require('mime').b64
assert(type(b64enc) == "function", "error loading Base64 encode module")

-----------------------------------------------------------------------------------------
function Kinvey:initialize(appkey, appSecret)
   
   -- Authorization for app-level access
   self.appLevelAuth  = "Basic " .. b64enc(appkey..":"..appSecret)
   self.userLevelAuth = nil

   -- Create header for app-level access
   self.headers = { 
      ["Authorization"] = self.appLevelAuth,
      ["Content-Type"]  = "application/json",
   }

   -- Extra arg list
   self.extraArgList = {
      appkey = appkey
   }

   -- Initialize class
   self.rest = Rest:new(self, "kinvey")

end

-----------------------------------------------------------------------------------------
function Kinvey:logout()
   self.headers.Authorization = self.appLevelAuth
   self.userData = nil
end

-----------------------------------------------------------------------------------------
function Kinvey:callMethod(name, t, ...)
   local arg = {n=select('#', ...), ...}
   local preCallback = nil

   -- Change authorization header if this is the login call
   if name == "login" then
      self.headers.Authorization = "Basic " .. b64enc(arg[1]..":"..arg[2])
      preCallback = function(r)
         self.userData = r.data
      end
   end

   -- Make the rest call
   self.rest:call(name, t, self.headers, self.extraArgList, preCallback, ...)
end
