version '1.2.0'

server_scripts {
	'config.lua',
	'@es_extended/locale.lua',
	'@mysql-async/lib/MySQL.lua',
	'locales/en_US.lua',
	'locales/fr_FR.lua',
	'server/whitelist_sv.lua'
}

client_scripts {
	'client/whitelist_cl.lua'
}

dependencies {
	'es_extended',
	'mysql-async'
}