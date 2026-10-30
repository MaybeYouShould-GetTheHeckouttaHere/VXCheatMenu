def check(value,message)
  raise message unless value
  $headless_checks=($headless_checks || 0)+1
end
# Actual filesystem round trips occur in the isolated WASI scratch directory.
VXCheat.no_clip=true
VXCheat.no_encounters=true
VXCheat.toggle_god(1)
VXCheat.bind('toggle','ctrl b')
VXCheat::Storage.locations << ['宿屋 / Inn',2,4,5,6]
VXCheat::Storage.save_locations
VXCheat::Storage.load
check(VXCheat.no_clip && VXCheat.no_encounters && VXCheat.god?(1),'flags did not persist')
check(VXCheat.binding('toggle')=='ctrl b','shortcut did not persist')
check(VXCheat::Storage.locations==[['宿屋 / Inn',2,4,5,6]],'Unicode location did not persist')
begin
  VXCheat.bind('quick_save','ctrl b')
  raise 'duplicate shortcut accepted'
rescue RuntimeError => e
  raise unless e.message.include?('Conflict')
end
check($game_player.passable?(1,1,6),'no clip did not bypass collision')
check(!$game_player.passable?(19,1,6),'no clip left map bounds')
check($game_player.encounter_progress_value==0,'encounter suppression failed')
check(!$game_player.encounter,'suppression failed when encounter count was already exhausted')
VXCheat.no_encounters=false
check($game_player.encounter,'encounters did not resume')
VXCheat::Storage.set('key.toggle','invalid key')
check(VXCheat.binding('toggle')=='ctrl c','corrupt menu shortcut did not fall back')
VXCheat.bind('toggle','ctrl b')
VXCheat.health($game_party.members,1)
check($game_party.members.last.hp==1,'party wound action failed')
$game_party.members.first.refresh
check($game_party.members.first.hp==100 && $game_party.members.first.tp==100,'god mode refresh failed')
$game_party.members.first.pay_skill_cost(nil)
check(!$game_party.members.first.instance_variable_get(:@paid),'god mode paid a skill cost')
$game_party.members.last.pay_skill_cost(nil)
check($game_party.members.last.instance_variable_get(:@paid),'normal skill cost was bypassed')
VXCheat.no_clip=false
check(!$game_player.passable?(1,1,6),'collision not restored')
check(VXCheat::Names.map_path(2)=='Town / Inn','map ancestry is wrong')
# Every panel must render in both map and battle contexts, with populated data.
ui=VXCheat::Overlay.new
[Scene_Map,Scene_Battle].each do |scene|
  SceneManager.scene=scene.new
  VXCheat.panels.each do |name,block|
    ui.select_panel(name)
    ui.render
    check(!ui.instance_variable_get(:@regions).empty?,"no controls: #{name}")
    check(ui.instance_variable_get(:@failed_panel).nil?,"panel failed: #{name}: #{ui.instance_variable_get(:@failed_panel)}")
  end
end
SceneManager.scene=Scene_Map.new
# Exercise real inline-field commit behavior, validation, and inventory writes.
ui.select_panel('General')
ui.render
ui.instance_variable_get(:@regions).find { |r| r[0][0]==214 && r[0][1]==121 }[1].call
edit=ui.instance_variable_get(:@edit)
check(edit && edit[:id]=='gold','gold field could not be focused')
edit[:text]='4321'
ui.commit
check($game_party.gold==4321,'gold field commit failed')
ui.instance_variable_get(:@regions).find { |r| r[0][0]==214 && r[0][1]==121 }[1].call
ui.instance_variable_get(:@edit)[:text]='invalid'
ui.commit
check($game_party.gold==4321,'invalid value mutated gold')
ui.select_panel('Item')
ui.render
regions=ui.instance_variable_get(:@regions)
regions.find { |r| r[0][0]==601 && r[0][1]==187 }[1].call
ui.instance_variable_get(:@edit)[:text]='12'
ui.commit
check($game_party.item_number($data_items[1])==12,'inventory commit failed')
# Search returns matching names and IDs, without altering source data.
ui.state[:search]='Potion 13'
ui.render
draw=ui.instance_variable_get(:@bitmap).operations
check(draw.any? { |op| op[0]=='text' && op[5]=='Potion 13' },'search did not find item')
check(!draw.any? { |op| op[0]=='text' && op[5]=='Potion 2' },'search did not filter item')
# Modal lifetime does not replace the live scene.
scene=SceneManager.scene
VXCheat.open
check(SceneManager.scene.equal?(scene),'overlay replaced game scene')
VXCheat.close
check(SceneManager.scene.equal?(scene),'closing overlay replaced game scene')
VXCheat::Storage.set('game_speed','2')
before=Graphics.instance_variable_get(:@frames) || 0
10.times { Graphics.update }
check(Graphics.instance_variable_get(:@frames)-before==5,'speed multiplier did not adjust render waits')
VXCheat::Storage.set('speed_scope','battle')
check(VXCheat.speed_rate==1.0,'battle-only speed affected map')
SceneManager.scene=Scene_Battle.new
check(VXCheat.speed_rate==2.0,'battle-only speed did not apply in battle')
SceneManager.scene=Scene_Map.new
VXCheat::Storage.set('game_speed','1')
VXCheat::Storage.set('speed_scope','all')
ui.dispose
check(!$game_party.members.first.respond_to?(:actor_id),'actor double accidentally exposes the MV actor API')
check(VXCheat.actor_id($game_party.members.first)==1,'VX Ace actor id adapter failed')
fast_ui=VXCheat::Overlay.new
fast_ui.select_panel('Stats/Level')
fast_ui.render
draw=fast_ui.instance_variable_get(:@bitmap).operations
check(draw.any? { |op| op[0]=='text' && op[5]=='Max HP' },'Stats did not draw parameter fields')
fast_ui.select_panel('General')
fast_ui.render
sprite=fast_ui.instance_variable_get(:@sprite)
scale=sprite.zoom_x
native=VXCheat::Native
native.instance_variable_set(:@text,'')
native.instance_variable_set(:@wheel,0)
native.instance_variable_set(:@down,{})
native.instance_variable_set(:@old,{})
native.instance_variable_set(:@x,sprite.x+260*scale)
native.instance_variable_set(:@y,sprite.y+80*scale)
fast_ui.update
clears,draws=Bitmap.clear_calls,Bitmap.draw_calls
180.times do |frame|
  native.instance_variable_set(:@x,sprite.x+(260+frame%20)*scale)
  fast_ui.update
end
check(Bitmap.clear_calls==clears,'mouse movement inside a widget redrew the whole card')
check(Bitmap.draw_calls==draws,'idle UI rasterized text')
check(fast_ui.instance_variable_get(:@cursor).x==native.x,'cursor did not move independently')
fast_ui.render
check(Bitmap.draw_calls==draws,'unchanged labels were not reused from the text cache')
$broken_panel_calls=0
VXCheat.register('Broken test') { |view| $broken_panel_calls+=1; raise 'fixture panel failure' }
fast_ui.select_panel('Broken test')
fast_ui.render
check(fast_ui.instance_variable_get(:@failed_panel),'panel error was not isolated')
draw=fast_ui.instance_variable_get(:@bitmap).operations
check(draw.any? { |op| op[0]=='text' && op[5]=='General' },'panel failure erased sidebar navigation')
check(draw.any? { |op| op[0]=='text' && op[5]=='This panel could not be drawn.' },'panel failure left a black canvas')
5.times { fast_ui.render }
check($broken_panel_calls==1,'failed panel was retried in a render loop')
check(File.read('cheat-settings/ui-error.log').include?('fixture panel failure'),'panel exception was not logged')
fast_ui.select_panel('General')
fast_ui.render
check(fast_ui.instance_variable_get(:@failed_panel).nil?,'navigation did not recover after panel failure')
300.times { |i| fast_ui.text(214,50,100,24,"cache fixture #{i}") }
check(fast_ui.instance_variable_get(:@text_cache).size<=256,'text cache grew without a bound')
fast_ui.dispose
VXCheat.instance_variable_get(:@panels).reject! { |p| p[0]=='Broken test' }
VXCheat.instance_variable_set(:@sorted_panels,nil)
# Exercise the display backend without a window; physical pointer coordinates
# must not be interpreted in the game's 640x480 coordinate system.
Win32API.ui_enabled=true
Win32API.ui_geometry=[1000,200,900,514,1334,303,1]
native.instance_variable_set(:@hwnd,123)
native.instance_variable_set(:@down,{})
native.instance_variable_set(:@old,{})
native.instance_variable_set(:@wheel,0)
display_ui=VXCheat::Overlay.new
check(display_ui.native?,'display renderer was not selected')
check(!display_ui.instance_variable_get(:@sprite).visible,'game-resolution card remained visible')
check(Win32API.ui_calls.any? { |name,args| name=='UIText' && args.size==7 },'native text was not drawn with the correct ABI')
check(Win32API.ui_calls.any? { |name,args| name=='UIFill' && args.size==5 },'native rectangles used the wrong ABI')
display_ui.update
check((display_ui.instance_variable_get(:@mx)-259.77).abs<1,'physical mouse X was not mapped to UI coordinates')
check((display_ui.instance_variable_get(:@my)-80.15).abs<1,'physical mouse Y was not mapped to UI coordinates')
clears=Bitmap.clear_calls
native_calls=Win32API.ui_calls.count { |name,args| name=='UIText' }
120.times { display_ui.update }
check(Bitmap.clear_calls==clears,'native idle rendering touched the game framebuffer')
check(Win32API.ui_calls.count { |name,args| name=='UIText' }==native_calls,'native idle rendering repainted text')
native.instance_variable_set(:@down,{1=>true})
native.instance_variable_set(:@old,{})
before=VXCheat.no_clip
display_ui.update
check(VXCheat.no_clip!=before,'clicks on display-resolution controls did not map correctly')
native.instance_variable_set(:@down,{})
native.instance_variable_set(:@old,{})
display_ui.switch_renderer
check(!display_ui.native? && display_ui.instance_variable_get(:@sprite).visible,'fallback renderer did not activate')
display_ui.switch_renderer
check(display_ui.native?,'native renderer could not be restored')
display_ui.dispose
Win32API.ui_enabled=false
native.instance_variable_set(:@hwnd,nil)
VXCheat::Translator.start(true)
check(VXCheat::Translator.message.include?('Translating'),'test request did not start')
Win32API.finish('"test"')
VXCheat::Translator.update
check(VXCheat::Translator.message.include?('available'),'translation test failed')
check(VXCheat::Translator.decode('"\\u5bbf\\u5c4b"')=='宿屋','JSON response decoding failed')
VXCheat::Storage.set('translate_enabled','1')
VXCheat::Translator.start
Win32API.finish("TownEN\nInnEN\nDoorEN\nQuestEN")
VXCheat::Translator.update
check(VXCheat::Names.get('map',1,'')=='TownEN','translated map was not applied')
check(VXCheat::Names.get('switch',1,'')=='DoorEN','translated switch was not applied')
VXCheat::Names.load
check(VXCheat::Names.get('variable',1,'')=='QuestEN','translation cache did not persist')
VXCheat::Translator.start
Win32API.finish('wrong number of lines')
VXCheat::Translator.update
check(VXCheat::Translator.message.include?('one line'),'malformed response was not rejected')
check(VXCheat::Names.get('map',1,'')=='TownEN','bad response corrupted cached names')
puts 'Persistence, Unicode bookmarks, collision bounds, shortcut conflicts, all panels, numeric fields, search, and modal lifetime passed.'
