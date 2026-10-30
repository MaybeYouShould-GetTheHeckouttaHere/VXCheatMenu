VXCheat.register('General') do |ui|
  ui.section('Edit')
  ui.checkbox('No Clip',VXCheat.no_clip) { |v| VXCheat.no_clip = v }
  ui.field('gold','Gold',$game_party.gold,0,$game_party.max_gold) { |v| $game_party.gain_gold(v-$game_party.gold) }
  speed = VXCheat::Storage.bool('fixed_speed') ? VXCheat::Storage.number('move_speed',1,10) : $game_player.move_speed
  ui.slider('move','Move Speed',speed,1,10,0.5) do |v|
    VXCheat::Storage.set('move_speed',v)
    $game_player.instance_variable_set(:@move_speed,v)
  end
  ui.checkbox('Fixed',VXCheat::Storage.bool('fixed_speed')) do |v|
    VXCheat::Storage.set('move_speed',$game_player.move_speed) if v
    VXCheat::Storage.set('fixed_speed',v ? '1' : '0')
  end
  ui.slider('game','Game Speed',VXCheat::Storage.number('game_speed',0.1,10),0.1,10,0.1) { |v| VXCheat::Storage.set('game_speed',v) }
  ui.buttons([['All: ' + (VXCheat::Storage.get('speed_scope') == 'all' ? 'ON' : 'OFF'), proc { VXCheat::Storage.set('speed_scope','all') }],
    ['Battle: ' + (VXCheat::Storage.get('speed_scope') == 'battle' ? 'ON' : 'OFF'), proc { VXCheat::Storage.set('speed_scope','battle') }],
    ['Reset x1',proc { VXCheat::Storage.set('game_speed','1') }]])
  ui.section('Quick Actions')
  ui.buttons([['To Title',proc { VXCheat.action('title') }], ['Open Save',proc { VXCheat.action('save') }], ['Open Load',proc { VXCheat.action('load') }]])
end

VXCheat.register('Shortcuts') do |ui|
  ui.buttons([['Restore defaults',proc {
    VXCheat::DEFAULT_KEYS.each { |id,key| VXCheat::Storage.values.delete('key.' + id) }
    VXCheat::Storage.save
  }]])
  ui.search
  keys = ui.filtered(VXCheat::DEFAULT_KEYS.keys) { |id| VXCheat::KEY_LABELS[id] + VXCheat.binding(id) }
  rows = keys.map do |id|
    [VXCheat::KEY_LABELS[id], [VXCheat.binding(id).empty? ? 'No Shortcut' : VXCheat.binding(id).upcase, proc { ui.capture(id) }, VXCheat::Overlay::FIELD]]
  end
  ui.table(['Name','Shortcut'],[270,198],rows)
  ui.section('Parameters')
  ui.field('save_slot','Quick save slot',VXCheat::Storage.number('quick_save_slot',1,DataManager.savefile_max).to_i,1,DataManager.savefile_max) { |v| VXCheat::Storage.set('quick_save_slot',v) }
  ui.field('load_slot','Quick load slot',VXCheat::Storage.number('quick_load_slot',1,DataManager.savefile_max).to_i,1,DataManager.savefile_max) { |v| VXCheat::Storage.set('quick_load_slot',v) }
  ui.field('shortcut_speed','Set speed shortcut parameter',VXCheat::Storage.number('shortcut_speed',1,10).to_i,1,10) { |v| VXCheat::Storage.set('shortcut_speed',v) }
  ui.field('skip_accel','Message skip acceleration',VXCheat::Storage.number('skip_accelerate',1,50).to_i,1,50) { |v| VXCheat::Storage.set('skip_accelerate',v) }
  ui.section('F12: engine reset (RGSS3 has no Chromium dev tools)')
end

VXCheat.register('Settings / Appearance') do |ui|
  ui.section('Appearance - display resolution, independent of the game')
  ui.slider('ui_size','UI Size (%)',VXCheat::Storage.number('ui_size',65,150),65,150,5) { |v| VXCheat::Storage.set('ui_size',v.to_i) }
  ui.slider('ui_text','Text Size (%)',VXCheat::Storage.number('ui_text',90,150),90,150,5) { |v| VXCheat::Storage.set('ui_text',v.to_i) }
  ui.section('Drag the header to move. Ctrl+wheel resizes the card.')
  ui.buttons([[ui.native? ? 'Renderer: display resolution' : 'Renderer: game canvas',proc { ui.switch_renderer }]])
  ui.section('Ctrl+Shift+F10 switches rendering if the card is hidden.')
  ui.section('Cheat settings: ./cheat-settings/')
  ui.section('Flags, shortcuts, speed and locations persist separately.')
  ui.section('Game saves do not contain the cheat settings.')
  ui.buttons([['Reset cheat flags',proc {
    ['no_clip','no_encounters','god_ids','fixed_speed','game_speed'].each do |key|
      VXCheat::Storage.values[key] = VXCheat::Storage::DEFAULTS[key]
    end
    VXCheat::Storage.save
  }]])
end

VXCheat.register('Settings / Translate') do |ui|
  ui.section('Translation: local display-name overrides')
  ui.section('Optional UTF-8 cheat-settings/translations.tsv:')
  ui.section('category<TAB>id<TAB>display name')
  ui.section('Categories: item, weapon, armor, actor, map, switch, variable')
  ui.buttons([['Reload translations',proc { VXCheat::Names.load }]])
  ui.section('Translation server')
  ui.checkbox('Enable',VXCheat::Storage.bool('translate_enabled')) { |v| VXCheat::Storage.set('translate_enabled',v ? '1' : '0') }
  ui.section('Start ezTransWeb or eztrans-server before translating.')
  ui.buttons(['ezTransWeb','ezTransServer','custom'].map { |name|
    [name + (VXCheat::Storage.get('translate_endpoint') == name ? ' *' : ''),proc { VXCheat::Storage.set('translate_endpoint',name) }]
  })
  if VXCheat::Storage.get('translate_endpoint') == 'custom'
    ui.buttons([['GET',proc { VXCheat::Storage.set('translate_method','get') }],['POST',proc { VXCheat::Storage.set('translate_method','post') }]])
    ui.field('translate_url','URL Pattern (${TEXT} placeholder)',VXCheat::Storage.get('translate_url')) { |v| VXCheat::Storage.set('translate_url',v) }
    ui.field('translate_body','POST body (${TEXT} placeholder)',VXCheat::Storage.get('translate_body')) { |v| VXCheat::Storage.set('translate_body',v) }
  end
  ui.field('translate_chunk','Chunk size',VXCheat::Storage.number('translate_chunk',1,500).to_i,1,500) { |v| VXCheat::Storage.set('translate_chunk',v) }
  ['variables','switches','maps'].each do |target|
    ui.checkbox('Translate '+target,VXCheat::Storage.bool('translate_'+target)) { |v| VXCheat::Storage.set('translate_'+target,v ? '1' : '0') }
  end
  ui.buttons([['Test availability',proc { VXCheat::Translator.start(true) }],['Translate names',proc { VXCheat::Translator.start }]])
  ui.section(VXCheat::Translator.message)
end
