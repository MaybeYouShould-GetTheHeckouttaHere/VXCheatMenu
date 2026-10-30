# encoding: utf-8
module VXCheat
  VERSION = '0.3.0'
  DEFAULT_KEYS = {'toggle'=>'ctrl c', 'locations'=>'ctrl m', 'quick_save'=>'ctrl s',
    'quick_load'=>'ctrl q', 'save'=>'ctrl [', 'load'=>'ctrl ]', 'title'=>'ctrl t',
    'victory'=>'ctrl v', 'defeat'=>'ctrl d', 'escape'=>'ctrl e', 'noclip'=>'alt w',
    'enemy_wound'=>'alt 1', 'enemy_recover'=>'alt 0', 'party_wound'=>'alt 2',
    'party_recover'=>'alt 9', 'speed'=>'', 'skip'=>''}
  KEY_LABELS = {'toggle'=>'Toggle cheat window', 'locations'=>'Save Locations tab',
    'quick_save'=>'Quick save', 'quick_load'=>'Quick load', 'save'=>'Open save',
    'load'=>'Open load', 'title'=>'Go to title', 'victory'=>'Force victory',
    'defeat'=>'Force defeat', 'escape'=>'Force escape', 'noclip'=>'Toggle no clip',
    'enemy_wound'=>'Enemies HP = 1', 'enemy_recover'=>'Recover enemies',
    'party_wound'=>'Party HP = 1', 'party_recover'=>'Recover party',
    'speed'=>'Set movement speed', 'skip'=>'Hold to skip messages'}
  @panels = []
  class << self
    attr_reader :overlay
    attr_accessor :message_pause
    def panels
      order = ['General','Shortcuts','HP/MP/Battle','Stats/Level','Item','Weapon','Armor',
        'Clear States','Variables','Switches','Save Locations','Teleport','Settings / Appearance','Settings / Translate']
      @sorted_panels ||= @panels.sort_by { |p| order.index(p[0]) || order.size }
    end
    def register(name, &draw); @panels << [name, draw]; @sorted_panels = nil; end
    def actor_id(actor)
      actor.respond_to?(:id) ? actor.id : actor.actor_id
    end
    def no_clip; Storage.bool('no_clip'); end
    def no_clip=(value); Storage.set('no_clip', value ? '1' : '0'); end
    def no_encounters; Storage.bool('no_encounters'); end
    def no_encounters=(value); Storage.set('no_encounters', value ? '1' : '0'); end
    def god?(id); Storage.get('god_ids').to_s.split(',').include?(id.to_s); end
    def toggle_god(id)
      ids = Storage.get('god_ids').to_s.split(',')
      ids.include?(id.to_s) ? ids.delete(id.to_s) : ids.push(id.to_s)
      Storage.set('god_ids', ids.join(','))
      if god?(id)
        $game_actors[id].recover_all
        $game_actors[id].tp = $game_actors[id].max_tp
      end
    end
    def binding(id)
      value = Storage.get('key.' + id)
      return DEFAULT_KEYS[id] if value.nil?
      keys = value.split(' ')
      return DEFAULT_KEYS[id] if id == 'toggle' && keys.empty?
      return value if keys.empty?
      modifier_only = id == 'skip' && (keys - ['ctrl','alt','shift']).empty?
      modifiers = keys[0...-1]
      valid = Native::KEY_NAMES.key?(keys.last) && !['ctrl','alt','shift'].include?(keys.last) &&
        (modifiers - ['ctrl','alt','shift']).empty? && modifiers.uniq.size == modifiers.size
      valid || modifier_only ? value : DEFAULT_KEYS[id]
    end
    def bind(id, value)
      raise 'The menu toggle requires a shortcut' if id == 'toggle' && value.empty?
      raise 'Unknown shortcut action' unless DEFAULT_KEYS.key?(id)
      conflict = DEFAULT_KEYS.keys.find { |k| k != id && binding(k) == value && !value.empty? }
      raise "Conflict with #{KEY_LABELS[conflict]}" if conflict
      Storage.set('key.' + id, value)
    end
    def close
      @overlay.dispose if @overlay
      @overlay = nil
      Native.enable(false)
    end
    def open(panel = nil)
      @overlay ||= Overlay.new
      @overlay.select_panel(panel) if panel
      Native.enable(true)
    end
    def toggle(panel = nil)
      if @overlay && (!panel || @overlay.panel_name == panel)
        close
      else
        open(panel)
      end
    end
    def battle?; SceneManager.scene.is_a?(Scene_Battle); end
    def map?; SceneManager.scene.is_a?(Scene_Map); end
    def enemies; battle? ? $game_troop.members : []; end
    def health(group, value)
      group.each { |a| value == :recover ? a.recover_all : a.hp = value }
    end
    def battle_action(action)
      raise 'This action requires a battle' unless battle?
      close
      @pending_battle = action
    end
    def perform_battle_action
      return unless @pending_battle
      action, @pending_battle = @pending_battle, nil
      case action
      when :victory; BattleManager.process_victory
      when :defeat; BattleManager.process_defeat
      when :escape; BattleManager.process_abort
      when :abort; BattleManager.abort
      end
    end
    def teleport(id, x, y, dir = $game_player.direction)
      raise 'Teleport is only available on the map' unless map?
      map = load_data(sprintf('Data/Map%03d.rvdata2', id))
      raise 'Coordinates outside map' unless x >= 0 && y >= 0 && x < map.width && y < map.height
      close
      $game_player.reserve_transfer(id, x, y, dir)
    end
    def action(id)
      case id
      when 'toggle'; toggle
      when 'locations'; toggle('Save Locations')
      when 'noclip'; self.no_clip = !no_clip
      when 'party_wound'; health($game_party.members, 1)
      when 'party_recover'; health($game_party.members, :recover)
      when 'enemy_wound'; health(enemies, 1)
      when 'enemy_recover'; health(enemies, :recover)
      when 'victory','defeat','escape'; battle_action(id.to_sym)
      when 'quick_save'
        raise 'Quick save is only available on the map' unless map?
        $game_system.on_before_save
        slot = Storage.number('quick_save_slot', 1, DataManager.savefile_max).to_i - 1
        raise 'Save failed' unless DataManager.save_game(slot)
        Sound.play_save
      when 'quick_load'
        slot = Storage.number('quick_load_slot', 1, DataManager.savefile_max).to_i - 1
        raise 'Load failed' unless DataManager.load_game(slot)
        close
        $game_system.on_after_load
        SceneManager.clear
        SceneManager.goto(Scene_Map)
      when 'save','load'
        raise 'Save/load screens are only available on the map' unless map?
        close
        SceneManager.call(id == 'save' ? Scene_Save : Scene_Load)
      when 'title'
        close
        SceneManager.clear
        SceneManager.goto(Scene_Title)
      when 'speed'
        Storage.set('fixed_speed', '0')
        $game_player.instance_variable_set(:@move_speed, Storage.number('shortcut_speed', 1, 10))
      end
      @overlay.invalidate if @overlay
    end
    def skip?
      keys = binding('skip').to_s.split(' ')
      return false if keys.empty?
      return Native.modifiers.sort == keys.sort if (keys - ['ctrl','alt','shift']).empty?
      Native.modifiers.sort == keys[0...-1].sort && Native.down?(keys.last)
    end
    def tick(scene)
      Native.update
      Translator.update
      if @overlay
        Graphics.update
        Input.update
        if Native.chord?('ctrl shift f10')
          @overlay.switch_renderer
          return true
        end
        shortcut = !@overlay.editing? && DEFAULT_KEYS.keys.find { |id| id != 'skip' && Native.chord?(binding(id)) }
        if shortcut
          action(shortcut)
        else
          @overlay.update
        end
        return true
      end
      DEFAULT_KEYS.keys.each do |id|
        next if id == 'skip'
        if Native.chord?(binding(id))
          action(id)
          Graphics.update
          Input.update
          return true
        end
      end
      perform_battle_action
      SceneManager.scene != scene
    rescue StandardError => e
      open
      @overlay.notice = e.message
      true
    end
    def speed_rate
      return 1.0 if @overlay
      return 1.0 unless map? || battle?
      return Storage.number('skip_accelerate', 1, 50) if skip?
      return 1.0 if Storage.get('speed_scope') == 'battle' && !battle?
      Storage.number('game_speed', 0.1, 10)
    end
  end
end

[Scene_Map, Scene_Battle].each do |klass|
  klass.class_eval do
    alias vxcheat_original_update update
    def update
      return if VXCheat.tick(self)
      vxcheat_original_update
    end
  end
end

module Graphics
  class << self
    alias vxcheat_original_update update
    def update
      rate = VXCheat.speed_rate
      @vxcheat_budget = (@vxcheat_budget || 0.0) + 1.0 / rate
      frames = @vxcheat_budget.floor
      @vxcheat_budget -= frames
      frames.times { vxcheat_original_update }
    end
  end
end

class Game_Player
  alias vxcheat_passable passable?
  def passable?(x, y, d)
    if VXCheat.no_clip
      return $game_map.valid?($game_map.round_x_with_direction(x, d), $game_map.round_y_with_direction(y, d))
    end
    vxcheat_passable(x, y, d)
  end
  alias vxcheat_encounter encounter_progress_value
  def encounter_progress_value; VXCheat.no_encounters ? 0 : vxcheat_encounter; end
  alias vxcheat_encounter_start encounter
  def encounter; VXCheat.no_encounters ? false : vxcheat_encounter_start; end
  alias vxcheat_real_speed real_move_speed
  def real_move_speed
    VXCheat::Storage.bool('fixed_speed') ? VXCheat::Storage.number('move_speed',1,10) + (dash? ? 1 : 0) : vxcheat_real_speed
  end
end
class Game_BattlerBase
  alias vxcheat_refresh refresh
  def refresh
    if is_a?(Game_Actor) && VXCheat.god?(VXCheat.actor_id(self))
      @hp, @mp, @tp = mhp, mmp, max_tp
    end
    vxcheat_refresh
  end
end
class Game_Battler
  alias vxcheat_pay_skill_cost pay_skill_cost
  def pay_skill_cost(skill)
    return if is_a?(Game_Actor) && VXCheat.god?(VXCheat.actor_id(self))
    vxcheat_pay_skill_cost(skill)
  end
end
class Window_Message
  alias vxcheat_show_fast update_show_fast
  def update_show_fast
    vxcheat_show_fast
    @show_fast = true if VXCheat.skip?
  end
  alias vxcheat_input_pause input_pause
  def input_pause
    return if VXCheat.skip?
    VXCheat.message_pause = true
    vxcheat_input_pause
  ensure
    VXCheat.message_pause = false
  end
end
module Input
  class << self
    alias vxcheat_trigger trigger?
    def trigger?(key)
      return true if key == :C && VXCheat.message_pause && VXCheat.skip?
      vxcheat_trigger(key)
    end
  end
end
