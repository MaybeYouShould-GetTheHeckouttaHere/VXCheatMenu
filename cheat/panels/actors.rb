VXCheat.register('Stats/Level') do |ui|
  actors = $game_party.all_members
  actor = actors.find { |a| VXCheat.actor_id(a) == ui.state[:actor] } || actors.first
  if actor
    ui.tabs(actors.map { |a| [VXCheat.actor_id(a),VXCheat::Names.get('actor',VXCheat.actor_id(a),a.name)] },VXCheat.actor_id(actor)) { |id| ui.state[:actor] = id }
    ui.checkbox('God Mode',VXCheat.god?(VXCheat.actor_id(actor))) { |v| VXCheat.toggle_god(VXCheat.actor_id(actor)) }
    ui.pair_fields(['level','Lv',actor.level,1,actor.max_level,proc { |v| actor.change_level(v,false) }],
      ['exp','EXP',actor.exp,0,actor.exp_for_level(actor.max_level),proc { |v| actor.change_exp(v,false) }])
    4.times do |pair|
      fields = (pair*2..pair*2+1).map do |id|
        ["param_#{id}",Vocab.param(id),actor.param(id),actor.param_min(id),actor.param_max(id),proc { |v|
          rate = actor.param_rate(id) * actor.param_buff_rate(id)
          raise 'Zero parameter multiplier' if rate == 0
          actor.add_param(id,((v-actor.param(id))/rate).round)
        }]
      end
      ui.pair_fields(*fields)
    end
  end
end

VXCheat.register('HP/MP/Battle') do |ui|
  ui.checkbox('Disable Random Encounter',VXCheat.no_encounters) { |v| VXCheat.no_encounters = v }
  ui.buttons([['Encounter',proc {
    raise 'Encounter requires a map' unless VXCheat.map?
    troop = $game_player.make_encounter_troop_id
    raise 'This map has no random encounters' unless $data_troops[troop]
    VXCheat.close
    BattleManager.setup(troop,true,false)
    BattleManager.on_encounter
    SceneManager.call(Scene_Battle)
  }], ['Victory',proc { VXCheat.battle_action(:victory) }],
    ['Defeat',proc { VXCheat.battle_action(:defeat) }], ['Escape',proc { VXCheat.battle_action(:escape) }], ['Abort',proc { VXCheat.battle_action(:abort) }]])
  [['Enemy',VXCheat.enemies],['Party',$game_party.members]].each do |title,members|
    ui.section(title)
    ui.buttons([['Set 0',proc { VXCheat.health(members,0) }],['Set 1',proc { VXCheat.health(members,1) }],
      ['Recovery',proc { VXCheat.health(members,:recover) }],['Fill TP',proc { members.each { |a| a.tp = a.max_tp } }]])
    rows = members.map do |actor|
      [actor.name,ui.number_cell("hp_#{actor.object_id}",actor.hp,0,actor.mhp) { |v| actor.hp = v },
       ui.number_cell("mp_#{actor.object_id}",actor.mp,0,actor.mmp) { |v| actor.mp = v }]
    end
    ui.table(['Name','HP','MP'],[244,112,112],rows,title.to_sym) unless members.empty?
  end
end

VXCheat.register('Clear States') do |ui|
  ui.buttons([['Clear party states',proc { $game_party.members.each { |a| a.clear_states; a.refresh } }],
    ['Clear enemy states',proc { VXCheat.enemies.each { |a| a.clear_states; a.refresh } }]])
  $game_party.members.each do |actor|
    ui.section(actor.name)
    actor.states.each do |s|
      ui.buttons([[s.name + ' - remove',proc { actor.remove_state(s.id) }]])
    end
  end
end
