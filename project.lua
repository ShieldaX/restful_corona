-- project.lua
-- config corona project
-- ========================================

-- touch global namespace
project_config = {
  name = 'RESTful App',
  version = '0.0.1',
}

require 'inspect'
class = require 'middleclass'
require 'Rest'
require 'Kinvey'

print(inspect(project_config))