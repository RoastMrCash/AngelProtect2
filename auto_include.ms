
#player stuff
proc(_angelprotect_create_player,@player){
	@uuid = replace(_uuid(@player),'-','')
	@array = import('AR.AngelProtect.Config')['New Player Defaults']
	@array['LastName'] = @player
	export('AR.AngelProtect.Players.'.@uuid,@array)
	_save('AR.AngelProtect.Players.'.@uuid)
}

proc(_angelprotect_player_data,@player){
	@uuid = replace(_uuid(@player),'-','')
	if(is_null(import('AR.AngelProtect.Players.'.@uuid))){
		if(has_value('AR.AngelProtect.Players.'.@uuid)){
			_load('AR.AngelProtect.Players.'.@uuid)
		}else{
			_angelprotect_create_player(@player)
		}
	}
	import('AR.AngelProtect.PlayerTimeouts')[@uuid] = time() + 1000 * 60 * 1
	return(import('AR.AngelProtect.Players.'.@uuid))
}

proc(_angelprotect_edit_player,@player,@index,@value){
	@uuid = replace(_uuid(@player),'-','')
	@array = _angelprotect_player_data(@player)
	@array[@index] = @value
	export('AR.AngelProtect.Players.'.@uuid,@array)
	_save('AR.AngelProtect.Players.'.@uuid)
}

#location / region / chunk stuff
proc(_angelprotect_location,@loc){
	if(@loc == '',@loc = ploc())
	@cloc = get_chunk_loc(@loc)
	@x = @cloc['x']
	@z = @cloc['z']
	@world = @cloc['world']
	return('APChunk_'.@x.'_'.@z.'_'.@world)
}

proc(_angelprotect_region,@cname){
	if(@cname == '', @cname = _angelprotect_location())
	if(is_array(@cname), @cname = _angelprotect_location(@cname))
	@cx = split('_',@cname,3)[1]
	@cz = split('_',@cname,3)[2]
	@world = split('_',@cname,3)[3]
	@region = _get_region_loc(array('x':@cx,'z':@cz,'world':@world,'0':@cx,'1':@cz,'2':@world))
	@x = @region['x']
	@z = @region['z']
	return(replace('APRegion_'.@x.'_'.@z.'_'.@world,'-','n'))
}

proc(_angelprotect_region_data,@rname){
	if(@rname == '', @rname = _angelprotect_region())
	if(is_array(@rname), @rname = _angelprotect_region(@rname))
	if(is_null(import('AR.AngelProtect.Regions.'.@rname))){
		_angelprotect_load_region(@rname)
	}
	return(import('AR.AngelProtect.Regions.'.@rname))
}

proc(_angelprotect_load_region,@rname){
	if(@rname == '', @rname = _angelprotect_region())
	if(is_array(@rname), @rname = _angelprotect_region(@rname))
	if(is_null(import('AR.AngelProtect.Regions.'.@rname))){
		_load('AR.AngelProtect.Regions.'.@rname)
		#broadcast(@rname.' loaded')
		array_push(import('AR.AngelProtect.LoadedRegionList'),@rname)
		_save('AR.AngelProtect.RegionTimeouts')
	}
	import('AR.AngelProtect.RegionTimeouts')[@rname] = time() + 1000 * 60 * 1
}

proc(_angelprotect_unload_region,@rname){
	export('AR.AngelProtect.Regions.'.@rname, null)
	array_remove_values(import('AR.AngelProtect.LoadedRegionList'),@rname)
}

proc(_angelprotect_save_region,@rname){
	_save('AR.AngelProtect.Regions.'.@rname)
}

#actual claim handeling

proc(_angelprotect_claim,@cname,@player,@force){
	if(@player == '', @player = player())
	@uuid = _uuid(@player)
	@playerdata = _angelprotect_player_data(@player)
	if(@force == '', @force = false)
	@rname = _angelprotect_region(@cname)
	@regiondata = _angelprotect_region_data(@rname)
	if(!@force){
	@cost = import('AR.AngelProtect.Config')['Costs']['Chunks']
	@total = _angelprotect_player_data(@player)['Runes-Total']
	@inuse = _angelprotect_player_data(@player)['Runes-In-Use']
	@available = @total - @inuse
	if(@cost > @available, return(false))
	}
	_angelprotect_edit_player(@player,'Runes-In-Use',@inuse + @cost)
	@chunkdata = associative_array(
		'Owner':@uuid,
		'Members':array(),
		'For-Rent':0,
		'Protections':associative_array(
			'Fire':true,
			'TNT':true,
			'Alarm':false,
			'PVP':false,
			'Mob-Spawn':false
		),
		'Permissions':associative_array(
			'Members':associative_array(
				'Build':true,
				'Break':true,
				'Teleport':true,
				'Switches':true
			),
			'Non-Members':associative_array(
				'Build':false,
				'Break':false,
				'Teleport':false,
				'Switches':false
			)
		)
	)
	@regiondata[@cname] = @chunkdata
	_save(@rname)
	@playerdata['Claims'][@cname] = @cost
	_angelprotect_edit_player(@player,'Claims',@playerdata['Claims'])
	return(true)
}

#town stuff
proc(_angelprotect_create_town,@townname,@owner,@homechunk,@force){
	if(@force == '', @force = false)
	@uuid = _uuid(@owner)
	@playerdata = _angelprotect_player_data(@owner)
	@rname = _angelprotect_region(@cname)
	@regiondata = _angelprotect_region_data(@rname)
	@townsarray = import('AR.AngelProtect.Towns')
	if(array_index_exists(@townsarray,@townname),return('townexists'))
		@towncreatecost = import('AR.AngelProtect.Config')['Costs']['Town-Create']
		@ownerrunes = _angelprotect_player_data(@owner)['Runes-Total']
		@townrunes = @ownerrunes - @towncreatecost
		@chunkcost = import('AR.AngelProtect.Config')['Costs']['Chunks']
		@townchunkcost = import('AR.AngelProtect.Config')['Costs']['Town-Chunks']
	if(!@force){
		if(@ownerrunes < @townchunkcost, return('insufficientrunes'))
		if(@townrunes < @chunkcost, return('insufficientrunes'))
	}
	@towndata = associative_array(
		'Displayname':@townname,
		'Owner': @uuid,
		'Assistants':array(),
		'Members':array(),
		'Daily-Tax':0,
		'Runes-Total':@townrunes,
		'Runes-In-Use':@chunkcost,
		'Home-Chunk':@homechunk
	)
	@chunkdata = associative_array(
		'Owner':'town:'.@townname,
		'Members':array(),
		'For-Rent':50,
		'Protections':associative_array(
			'Fire':true,
			'TNT':true,
			'Alarm':false,
			'PVP':false,
			'Mob-Spawn':false
		),
		'Permissions':associative_array(
			'Members':associative_array(
				'Build':true,
				'Break':true,
				'Teleport':true,
				'Switches':true
			),
			'Non-Members':associative_array(
				'Build':false,
				'Break':false,
				'Teleport':false,
				'Switches':false
			)
		)
	)
	@regiondata[@cname] = @chunkdata
	_save(@rname)
	@playerdata['Claims'][@cname] = @townchunkcost
	_angelprotect_edit_player(@player,'Claims',@playerdata['Claims'])
	return('success')
}
