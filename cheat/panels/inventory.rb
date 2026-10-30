[['Item',:$data_items,'item'],['Weapon',:$data_weapons,'weapon'],['Armor',:$data_armors,'armor']].each do |title,database,category|
  VXCheat.register(title) do |ui|
    ui.search
    ui.checkbox('Hide Nameless Items',ui.state[:nameless]) { |v| ui.state[:nameless] = v; ui.state[:page] = 0 }
    ui.checkbox('Only Owned Items',ui.state[:owned]) { |v| ui.state[:owned] = v; ui.state[:page] = 0 }
    items = eval(database.to_s).compact
    items = items.reject { |item| item.name.empty? } if ui.state[:nameless]
    items = items.select { |item| $game_party.item_number(item) > 0 } if ui.state[:owned]
    items = ui.filtered(items) { |item| "#{item.id} #{VXCheat::Names.get(category,item.id,item.name)} #{item.description}" }
    rows = items.map do |item|
      [VXCheat::Names.get(category,item.id,item.name),item.description.gsub(/[\r\n]/,' '),
       ui.number_cell("item_#{item.id}",$game_party.item_number(item),0,$game_party.max_item_number(item)) { |v| $game_party.gain_item(item,v-$game_party.item_number(item)) }]
    end
    ui.table(['Name','Description','Amount'],[160,224,84],rows)
  end
end
