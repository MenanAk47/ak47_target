fx_version 'adamant'
game 'gta5'
description 'Ak47 Target'
author 'MenanAk47'
version '1.1.0'

ui_page 'web/index.html'
--ui_page 'http://localhost:5173'

files {
    'web/index.html',
    'web/**/*'
}

shared_scripts {
    'shared/utils.lua',
}

client_scripts {
    'config.lua',
    'client/api.lua',
    'client/frameworks.lua',
    'client/zones.lua',
    'client/defaults.lua',
    'client/main.lua',
    'client/compat.lua',
}

server_scripts {
    'server/main.lua'
}

provides {
    'ox_target',
    'qtarget',
    'qb-target',
}