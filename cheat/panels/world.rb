VXCheat.register('Switches') do |ui|
  ui.search
  ui.checkbox('Hide Nameless Switches',ui.state[:nameless]) { |v| ui.state[:nameless] = v; ui.state[:page] = 0 }
  ids = ui.filtered((1...$data_system.switches.size).to_a) { |id| "#{id} #{VXCheat::Names.get('switch',id,$data_system.switches[id])}" }
  ids = ids.reject { |id| $data_system.switches[id].to_s.empty? } if ui.state[:nameless]
  ui.buttons([['Toggle all filtered switches',proc {
    value = !ids.all? { |id| $game_switches[id] }
    ids.each { |id| $game_switches[id] = value }
  }]])
  rows = ids.map do |id|
    [id,VXCheat::Names.get('switch',id,$data_system.switches[id]),[$game_switches[id] ? 'ON' : 'OFF',proc { $game_switches[id] = !$game_switches[id] }]]
  end
  ui.table(['ID','Name','Value'],[48,320,100],rows)
end

VXCheat.register('Variables') do |ui|
  ui.search
  ui.checkbox('Hide Nameless Variables',ui.state[:nameless]) { |v| ui.state[:nameless] = v; ui.state[:page] = 0 }
  ids = ui.filtered((1...$data_system.variables.size).to_a) { |id| "#{id} #{VXCheat::Names.get('variable',id,$data_system.variables[id])} #{$game_variables[id]}" }
  ids = ids.reject { |id| $data_system.variables[id].to_s.empty? } if ui.state[:nameless]
  rows = ids.map do |id|
    value = $game_variables[id]
    cell = if value.is_a?(Numeric)
      ui.number_cell("var_#{id}",value,-999999999999,999999999999,value.is_a?(Float) ? 0.1 : nil) { |v| $game_variables[id] = v }
    elsif value.is_a?(String)
      ui.number_cell("var_#{id}",value,nil,nil) { |v| $game_variables[id] = v }
    elsif value == true || value == false
      [value.to_s,proc { $game_variables[id] = !value }]
    else
      value.to_s
    end
    [id,VXCheat::Names.get('variable',id,$data_system.variables[id]),cell]
  end
  ui.table(['ID','Name','Value'],[48,280,140],rows)
end

VXCheat.register('Teleport') do |ui|
  ui.pair_fields(['x','X',ui.state[:x] || 0,0,9999,proc { |v| ui.state[:x] = v }],
    ['y','Y',ui.state[:y] || 0,0,9999,proc { |v| ui.state[:y] = v }])
  ui.search
  ui.checkbox('Hide Full Path Field',ui.state[:hide_path]) { |v| ui.state[:hide_path] = v }
  ids = ui.filtered($data_mapinfos.keys.sort) { |id| "#{id} #{VXCheat::Names.map_path(id)}" }
  rows = ids.map do |id|
    name = ui.state[:hide_path] ? VXCheat::Names.get('map',id,$data_mapinfos[id].name) : VXCheat::Names.map_path(id)
    [id,name,['Teleport',proc { ui.commit; VXCheat.teleport(id,ui.state[:x] || 0,ui.state[:y] || 0) }]]
  end
  ui.table(['ID','Map / full path','Action'],[48,320,100],rows)
end

VXCheat.register('Save Locations') do |ui|
  ui.section('Map: ' + VXCheat::Names.map_path($game_map.map_id))
  ui.field('alias','Location Alias',ui.state[:alias] || '') { |v| ui.state[:alias] = v }
  save_location = proc {
    ui.commit
    name = ui.state[:alias].to_s
    name = VXCheat::Names.map_path($game_map.map_id) if name.empty?
    VXCheat::Storage.locations << [name,$game_map.map_id,$game_player.x,$game_player.y,$game_player.direction]
    VXCheat::Storage.save_locations
    ui.state[:alias] = ''
  }
  ui.enter_action('alias',&save_location)
  ui.buttons([['+ Save current location',save_location]])
  ui.search
  entries = ui.filtered(VXCheat::Storage.locations.each_with_index.to_a) { |v| "#{v[0][0]} #{VXCheat::Names.map_path(v[0][1])}" }
  rows = entries.map do |location,index|
    [location[0],"#{location[1]} (#{location[2]},#{location[3]})",
      ['Go',proc { VXCheat.teleport(*location[1..4]) }],['Delete',proc {
        VXCheat::Storage.locations.delete_at(index)
        VXCheat::Storage.save_locations
      },VXCheat::Overlay::PINK]]
  end
  ui.table(['Name','Location','Recall','Remove'],[170,142,72,84],rows)
end
