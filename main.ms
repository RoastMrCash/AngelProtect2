
#load up config
export('AR.AngelProtect.Config',(yml_decode(read('../AngelProtect.yml'))))

#load town stuff
_load('AR.AngelProtect.Towns')

#create empty arrays for non-persistent data
export('AR.AngelProtect.TPInvites',associative_array())
export('AR.AngelProtect.ChunkPreviewers',associative_array())
export('AR.AngelProtect.RegionTimeouts',associative_array())
export('AR.AngelProtect.PlayerTimeouts',associative_array())
export('AR.AngelProtect.LoadedRegionList',array())

#unload regions that aren't in use to preserve ram
set_interval(1000 * 60,closure(
	foreach(import('AR.AngelProtect.RegionTimeouts'),@region,@timeout){
		if(@timeout < time()){
			_angelprotect_unload_region(@region)
			#broadcast(@region.' unloaded')
			array_remove(import('AR.AngelProtect.RegionTimeouts'),@region)
			continue(0)
		}
	}
	foreach(import('AR.AngelProtect.PlayerTimeouts'),@uuid,@timeout){
		if(@timeout < time()){
			export('AR.AngelProtect.Players.'.@uuid,null)
			#_angelprotect_unload_region(@region)
			#broadcast(@region.' unloaded')
			array_remove(import('AR.AngelProtect.PlayerTimeouts'),@region)
			continue(0)
		}
	}
))

#events
bind(player_join,null,null,@e){
	@world = pworld()
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region()
	}
}

bind(player_move,null,null,@e){
	@world = @e['to'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['to'])
	}
}

bind(block_place,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['location'])
	}
}

bind(block_break,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['location'])
	}
}

bind(player_interact,null,null,@e){
	if(@e['action'] == 'left_click_block' || @e['action'] == 'right_click_block'){
		@world = @e['location'][3]
		if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
			_angelprotect_load_region(@e['location'])
		}
	}
}

bind(entity_damage_player,null,null,@e){
	@world = ploc(@e['player'])
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(ploc(@e['player']))
	}
}

bind(creature_spawn,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['location'])
	}
}

bind(block_ignite,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['location'])
	}
}

bind(block_burn,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['location'])
	}
}

bind(player_teleport,null,null,@e){
	@world = @e['to'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['to'])
	}
}

bind(player_portal_travel,null,null,@e){
	@world = @e['location'][3]
	if(array_contains(import('AR.AngelProtect.Config')['Worlds'],@world)){
		_angelprotect_load_region(@e['to'])
	}
}

###Creeper Rollback and WG Region Protection
bind(entity_explode, null, null, @e,
	if(@e['type'] == 'CREEPER'){
		@blocks = @e['blocks']
		foreach(@blocks,@block){
			@type = get_block_at(@block)
			if(array_contains(array(54,146,61,23,158,154,84,47),reg_split(':',@type)[0])/* || _angelprotect_is_claimed(@block)*/){
				array_remove_values(@blocks, @block)
				continue(0)
			}else{
				set_timeout(250 * rand(28,56), closure(
					set_block_at(@block,@type,false)
				))
			}
		}
		modify_event('blocks',@blocks)
		modify_event('yield',0)
	}
	if(@e['type'] == 'PRIMED_TNT'){
		@blocks = @e['blocks']
		foreach(@blocks,@block){
			if(_angelprotect_is_tnt_safe(@block)){
				array_remove_values(@blocks, @block)
				continue(0)
			}
		}
		modify_event('blocks',@blocks)
	}
)
