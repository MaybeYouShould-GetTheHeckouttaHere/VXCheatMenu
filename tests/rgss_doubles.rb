Dir.chdir('/test')
class Win32API
  class << self
    attr_accessor :http_status,:http_response,:http_requests
    attr_accessor :ui_enabled,:ui_geometry,:ui_calls
    def finish(text); @http_response=text; @http_status=2; end
  end
  def initialize(dll,name,*args); @name = name; end
  def call(*args)
    if @name.start_with?('UI')
      self.class.ui_calls ||= []
      self.class.ui_calls << [@name,args]
      case @name
      when 'UIOpen'; return self.class.ui_enabled ? 1 : 0
      when 'UIPoll'; args[0].replace(self.class.ui_geometry.pack('l7')); return 0
      when 'UIMeasure'; return args[1]*9
      when 'UIMove'
        self.class.ui_geometry[0]+=args[0]
        self.class.ui_geometry[1]+=args[1]
      end
      return 1
    end
    case @name
    when 'TranslateStart'
      self.class.http_requests ||= []
      self.class.http_requests << args
      self.class.http_status=1
      return 1
    when 'TranslateStatus'; return self.class.http_status || 0
    when 'TranslateReset'
      return 0 if self.class.http_status==1
      self.class.http_status=0
      return 1
    when 'TranslateRead'
      response=self.class.http_response
      args[0][0,response.bytesize]=response
      self.class.http_status=0
      return response.bytesize
    end
    if @name == 'MoveFileExW'
      from,to = args[0..1].map { |v| v.dup.force_encoding('UTF-16LE').encode('UTF-8').delete("\0") }
      File.rename(from,to)
    end
    return 0 if ['Character','Wheel','GetAsyncKeyState'].include?(@name)
    1
  end
end
class Color
  attr_reader :values
  def initialize(*v); @values=v; end
  def red; @values[0]; end
  def green; @values[1]; end
  def blue; @values[2]; end
end
class Font
  attr_accessor :name,:size,:outline,:color
end
class Rect
  attr_reader :x,:y,:width,:height
  def initialize(x,y,w,h); @x,@y,@width,@height=x,y,w,h; end
end
class Bitmap
  attr_reader :font,:operations
  @@draw_calls,@@clear_calls=0,0
  def self.draw_calls; @@draw_calls; end
  def self.clear_calls; @@clear_calls; end
  def initialize(*v); @font=Font.new; @operations=[]; end
  def clear; @@clear_calls+=1; @operations=[]; end
  def fill_rect(x,y,w,h,color); @operations << ['rect',x,y,w,h,color.values]; end
  def draw_text(x,y,w,h,text,align=0)
    @@draw_calls+=1
    @operations << ['text',x,y,w,h,text,@font.color.values,align]
  end
  def blt(x,y,source,rect)
    source.operations.each do |operation|
      copy=operation.dup
      copy[1]+=x; copy[2]+=y
      @operations << copy
    end
  end
  def text_size(text); Struct.new(:width).new(text.length*8); end
  def dispose; end
end
class Sprite
  attr_accessor :bitmap,:z,:zoom_x,:zoom_y,:x,:y,:opacity,:visible
  def dispose; end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
  def self.update; @frames=(@frames||0)+1; end
end
module Input
  def self.update; end
  def self.trigger?(key); false; end
end
class Scene_Map
  def update; end
end
class Scene_Battle
  def update; end
end
class Scene_Save; end
class Scene_Load; end
class Scene_Title; end
module SceneManager
  @scene=Scene_Map.new
  class << self
    attr_accessor :scene
    def goto(klass); @scene=klass.new; end
    def call(klass); @scene=klass.new; end
    def clear; end
  end
end
class Game_Player
  attr_reader :move_speed,:x,:y,:direction
  def initialize; @move_speed=4; @x=5; @y=6; @direction=2; end
  def passable?(*args); false; end
  def encounter_progress_value; 1; end
  def encounter; true; end
  def real_move_speed; @move_speed; end
  def dash?; false; end
  def reserve_transfer(*args); @transfer=args; end
end
class Game_BattlerBase
  def refresh; end
end
class Game_Battler < Game_BattlerBase
  def pay_skill_cost(skill); @paid=true; end
end
class Game_Actor < Game_Battler
  attr_accessor :hp,:mp,:tp
  attr_reader :name,:level,:exp
  def id; @actor_id; end
  def initialize(id)
    @actor_id=id; @name="Actor #{id}"; @hp=20; @mp=10; @tp=0; @level=5; @exp=100
  end
  def mhp; 100; end
  def mmp; 50; end
  def max_tp; 100; end
  def recover_all; @hp=mhp; @mp=mmp; end
  def max_level; 99; end
  def exp_for_level(v); v*1000; end
  def param(id); 10; end
  def param_min(id); 0; end
  def param_max(id); 9999; end
  def param_rate(id); 1.0; end
  def param_buff_rate(id); 1.0; end
  def add_param(*args); end
  def change_level(v,*args); @level=v; end
  def change_exp(v,*args); @exp=v; end
  def states; []; end
  def clear_states; end
end
class Window_Message
  def update_show_fast; end
  def input_pause; end
end
module Vocab
  def self.param(id); ['Max HP','Max MP','ATK','DEF','MAT','MDF','AGI','LUK'][id]; end
end
class TestParty
  attr_reader :gold,:members
  def initialize; @gold=1234; @members=[Game_Actor.new(1),Game_Actor.new(2)]; @items={}; end
  def all_members; @members; end
  def max_gold; 99999999; end
  def gain_gold(v); @gold+=v; end
  def item_number(item); @items.fetch(item.id,0); end
  def max_item_number(item); 99; end
  def gain_item(item,v); @items[item.id]=item_number(item)+v; end
end
class TestMap
  def map_id; 1; end
  def valid?(x,y); x>=0 && y>=0 && x<20 && y<20; end
  def round_x_with_direction(x,d); d==6 ? x+1 : x; end
  def round_y_with_direction(y,d); d==2 ? y+1 : y; end
end
module DataManager
  def self.savefile_max; 16; end
end
$game_party=TestParty.new
$game_troop=TestParty.new
$game_player=Game_Player.new
$game_map=TestMap.new
$game_actors={1=>$game_party.members[0],2=>$game_party.members[1]}
$game_switches=Hash.new(false)
$game_variables=Hash.new(0)
$data_system=Struct.new(:switches,:variables).new(['','Door',''],['','Quest',''])
$data_mapinfos={1=>Struct.new(:name,:parent_id).new('Town',0),2=>Struct.new(:name,:parent_id).new('Inn',1)}
Item=Struct.new(:id,:name,:description)
$data_items=[nil]+(1..13).map { |i| Item.new(i,"Potion #{i}",'Restores HP') }
$data_weapons=$data_armors=$data_items
def load_data(path); Struct.new(:width,:height).new(20,20); end
