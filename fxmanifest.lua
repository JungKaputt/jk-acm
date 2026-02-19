fx_version 'cerulean'
game 'gta5'

author 'JungKaputt'
description 'Advanced Criminal Management (ACM)'
version '1.0.0' 

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_market.lua',
    'server/sv_turf.lua',
    'server/sv_org.lua',
    'server/sv_laundry.lua',
    'server/sv_dynamic_turf.lua' 
}

client_scripts {
    'client/cl_utils.lua',
    'client/cl_main.lua',
    'client/cl_airdrop.lua',
    'client/cl_turf.lua',
    'client/cl_laundry.lua',
    'client/cl_stash.lua',
    'client/cl_dynamic_turf.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/libs/*.js',
    'html/libs/*.css',
    
    'html/css/*.css',   
    'html/js/*.js',     
    
    'html/*.png',
    'html/*.jpg'
}

lua54 'yes'