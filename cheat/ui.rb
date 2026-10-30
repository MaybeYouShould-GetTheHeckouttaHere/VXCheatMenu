# encoding: utf-8
module VXCheat
  # A 700x400 dark card, 200px navigation tree, searchable tables and inline
  # fields, matching the source plugin's structure. Scales to the game canvas.
  class Overlay
    attr_reader :notice
    attr_reader :panel_name
    BG = Color.new(30,30,30)
    CARD = Color.new(48,48,48)
    FIELD = Color.new(66,66,66)
    WHITE = Color.new(238,238,238)
    MUTED = Color.new(175,175,175)
    ACCENT = Color.new(38,166,154)
    BLUE = Color.new(33,150,243)
    PINK = Color.new(233,30,99)
    def initialize
      @sprite = Sprite.new
      @sprite.bitmap = Bitmap.new(700,400)
      @sprite.z = 100000
      @scale = [Graphics.width / 720.0, Graphics.height / 420.0, 1.0].min
      @sprite.zoom_x = @sprite.zoom_y = @scale
      @sprite.x = (Graphics.width - 700 * @scale) / 2
      @sprite.y = (Graphics.height - 400 * @scale) / 2
      @bitmap = @sprite.bitmap
      @bitmap.font.name = ['Segoe UI','Meiryo','Arial']
      @bitmap.font.size = 16
      @bitmap.font.outline = false
      @text_cache = {}
      @cursor = Sprite.new
      @cursor.bitmap = Bitmap.new(9,15)
      12.times { |i| @cursor.bitmap.fill_rect(0,i,[i/2+1,7].min,1,WHITE) }
      @cursor.z = @sprite.z + 1
      @cursor.zoom_x = @cursor.zoom_y = @scale
      @cursor.visible = false
      @native_metrics = {}
      @native = Display.open
      @sprite.visible = false if @native
      @states, @regions = {}, []
      @nav_collapsed = {}
      select_panel('General')
      begin
        render
      rescue StandardError => error
        raise unless @native
        log_error(error)
        Display.close
        @native = false
        @sprite.visible = true
        @notice = 'Display UI unavailable; using game rendering. See ui-error.log.'
        render
      end
    end
    def disposed?; !!@disposed; end
    def dispose
      @disposed = true
      Display.close if @native
      @text_cache.each_value { |entry| entry[0].dispose }
      @text_cache.clear
      @cursor.bitmap.dispose
      @cursor.dispose
      @bitmap.dispose
      @sprite.dispose
    end
    def state; @states[@panel_name] ||= {}; end
    def invalidate; @dirty = true; end
    def native?; !!@native; end
    def switch_renderer
      if @native
        Display.close
        @native = false
        Storage.set('ui_renderer','game')
      else
        Storage.set('ui_renderer','native')
        @native = Display.open
      end
      @sprite.visible = !@native
      @cursor.visible = false
      @native_metrics.clear
      @window_drag = nil
      invalidate
    end
    def notice=(value)
      invalidate if @notice != value
      @notice = value
    end
    def editing?; !!(@edit || @capture); end
    def select_panel(name)
      return unless VXCheat.panels.any? { |p| p[0] == name }
      commit if @edit
      @capture = nil
      @panel_name, @scroll = name, 0
      @failed_panel = nil
      invalidate
    end
    def inside?(rect)
      @mx && @mx >= rect[0] && @my >= rect[1] && @mx < rect[0]+rect[2] && @my < rect[1]+rect[3]
    end
    def rect(x,y,w,h,color)
      @native ? Display.fill(x,y,w,h,color) : @bitmap.fill_rect(x,y,w,h,color)
    end
    def text(x,y,w,h,value,color = WHITE,align = 0)
      value = value.to_s
      key = [value,w,h,color.object_id,align]
      if @native
        Display.text(x,y,w,h,value,color,align)
        @text_regions << [[x,y,w,h],key]
        if inside?([x,y,w,h])
          measured = @native_metrics[value] ||= Display.measure(value)
          @native_metrics.shift while @native_metrics.size > 256
          @tooltip = value if measured > w
        end
        return
      end
      entry = @text_cache.delete(key)
      unless entry
        cached = Bitmap.new(w,h)
        cached.font.name = @bitmap.font.name
        cached.font.size = @bitmap.font.size
        cached.font.outline = @bitmap.font.outline
        cached.font.color = color
        cached.draw_text(0,0,w,h,value,align)
        entry = [cached,Rect.new(0,0,w,h),nil]
      end
      @text_cache[key] = entry
      @bitmap.blt(x,y,entry[0],entry[1])
      @text_cache.shift[1][0].dispose while @text_cache.size > 256
      @text_regions << [[x,y,w,h],key]
      if inside?([x,y,w,h])
        entry[2] ||= entry[0].text_size(value).width
        @tooltip = value if entry[2] > w
      end
    end
    def region(x,y,w,h,&action); @regions << [[x,y,w,h],action]; end
    def button_at(x,y,w,label,color = FIELD,&action)
      return unless y >= 38 && y + 27 <= 370
      box = [x,y,w,27]
      rect(x,y,w,27,inside?(box) ? BLUE : color)
      text(x+4,y,w-8,27,label,WHITE,1)
      region(*box,&action)
    end
    def line_y(height)
      y = @flow - @scroll
      @flow += height
      y
    end
    def section(label)
      y = line_y(26)
      text(214,y,468,24,label,MUTED) if y >= 38 && y+24 <= 370
    end
    def buttons(entries)
      y = line_y(35)
      width = (466 - (entries.size-1)*6) / entries.size
      entries.each_with_index { |entry,i| button_at(214+i*(width+6),y,width,entry[0],entry[2] || FIELD,&entry[1]) }
    end
    def checkbox(label, value, &apply)
      y = line_y(32)
      return unless y >= 38 && y+25 <= 370
      rect(216,y+5,16,16,value ? ACCENT : MUTED)
      text(216,y,16,26,value ? 'x' : '',WHITE,1)
      text(240,y,438,26,label)
      region(214,y,468,28) { commit; apply.call(!value) }
    end
    def field(id,label,value,min = nil,max = nil,step = nil,&apply)
      y = line_y(54)
      return unless y >= 38 && y+49 <= 370
      text(214,y,468,20,label,MUTED)
      field_at(id,214,y+21,468,27,value,min,max,step,&apply)
    end
    def field_at(id,x,y,w,h,value,min = nil,max = nil,step = nil,&apply)
      active = @edit && @edit[:id] == id
      rect(x,y,w,h,active ? BLUE : FIELD)
      display = if active
        at = @edit[:cursor] || @edit[:text].length
        @edit[:text][0...at] + '|' + @edit[:text][at..-1].to_s
      else
        value.to_s
      end
      text(x+6,y,w-12,h,display)
      entry = region(x,y,w,h) do
        unless @edit && @edit[:id] == id
          commit
          @edit = {:id=>id,:text=>value.to_s,:original=>value.to_s,:cursor=>value.to_s.length,:min=>min,:max=>max,:step=>step,:apply=>apply,:all=>true}
          @notice = 'Type to replace; Enter or click away to apply; Esc cancels.'
        end
      end
      entry.last << id
      @field_regions << entry.last
    end
    def enter_action(id,&action); @enter_actions[id] = action; end
    def tabs(entries,selected,&apply)
      y = line_y(35)
      return unless y >= 38 && y+27 <= 370
      start = state[:tab_start] || [entries.index { |v| v[0] == selected }.to_i-3,0].max
      start = [[start,0].max,[entries.size-4,0].max].min
      button_at(214,y,24,'<') { commit; state[:tab_start] = [start-1,0].max }
      visible = entries[start,4] || []
      w = (402-[visible.size-1,0].max*4)/[visible.size,1].max
      visible.each_with_index do |entry,i|
        button_at(244+i*(w+4),y,w,entry[1],entry[0] == selected ? BLUE : FIELD) { commit; apply.call(entry[0]) }
      end
      button_at(654,y,28,'>') { commit; state[:tab_start] = [start+1,[entries.size-4,0].max].min }
    end
    def pair_fields(left,right)
      y = line_y(54)
      return unless y >= 38 && y+49 <= 370
      [left,right].each_with_index do |field,i|
        id,label,value,min,max,apply = field
        x = 214+i*240
        text(x,y,228,20,label,MUTED)
        field_at(id,x,y+21,228,27,value,min,max,nil,&apply)
      end
    end
    def slider(id,label,value,min,max,step,&apply)
      value = [[value,min].max,max].min
      y = line_y(46)
      return unless y >= 38 && y+40 <= 370
      text(214,y,178,20,label,MUTED)
      text(610,y,68,20,sprintf('%.1f',value),WHITE,2)
      x, width = 242, 398
      rect(x,y+30,width,3,MUTED)
      t = (value-min).to_f/(max-min)
      rect(x,y+30,(width*t).to_i,3,PINK)
      rect((x+width*t-4).to_i,y+25,9,13,PINK)
      button_at(214,y+18,22,'<') { commit; apply.call([min,value-step].max) }
      button_at(650,y+18,28,'>') { commit; apply.call([max,value+step].min) }
      box = [x,y+21,width,22]
      region(*box) { commit; @drag = [box,min,max,step,apply]; drag_slider }
    end
    def drag_slider
      return unless @drag
      box,min,max,step,apply = @drag
      t = [[(@mx-box[0])/box[2].to_f,0].max,1].min
      apply.call((min + ((max-min)*t/step).round*step).round(4))
    end
    def commit
      return unless @edit
      edit, @edit = @edit, nil
      value = edit[:text]
      if edit[:min]
        value = edit[:step] && edit[:step] < 1 ? Float(value) : Integer(value,10)
        raise 'Value must be finite' if value.is_a?(Float) && !value.finite?
        raise "Value must be between #{edit[:min]} and #{edit[:max]}" unless value >= edit[:min] && value <= edit[:max]
      end
      edit[:apply].call(value) if edit[:apply]
      @notice = Storage.error || 'Applied'
    rescue StandardError => e
      @notice = e.message
    end
    def search
      field('search','Search...',state[:search] || '') { |v| state[:search] = v; state[:page] = 0 }
    end
    def filtered(items,&label)
      query = (state[:search] || '').downcase
      query.empty? ? items : items.select { |item| label.call(item).to_s.downcase.include?(query) }
    end
    # Entries are arrays of strings, field descriptions, or [button, callback].
    def table(headers, widths, entries, page_key = :page)
      pages = [(entries.size + 4) / 5,1].max
      state[page_key] = [[state[page_key] || 0,0].max,pages-1].min
      y = line_y(25)
      if y >= 38 && y+24 <= 370
        x = 214
        headers.each_with_index { |h,i| text(x+4,y,widths[i]-8,24,h,MUTED); x += widths[i] }
      end
      (entries[state[page_key]*5,5] || []).each do |row|
        y = line_y(32)
        next unless y >= 38 && y+30 <= 370
        rect(214,y+30,468,1,FIELD)
        x = 214
        row.each_with_index do |cell,i|
          w = widths[i]
          if cell.is_a?(Hash)
            field_at(cell[:id],x+3,y+2,w-6,27,cell[:value],cell[:min],cell[:max],cell[:step],&cell[:apply])
          elsif cell.is_a?(Array)
            button_at(x+3,y+2,w-6,cell[0],cell[2] || ACCENT,&cell[1])
          else
            text(x+4,y,w-8,30,cell)
          end
          x += w
        end
      end
      section("#{entries.size} entries  |  Page #{state[page_key]+1} / #{pages}")
      buttons([['< Previous',proc { commit; state[page_key] = [state[page_key]-1,0].max }],
        ['Next >',proc { commit; state[page_key] = [state[page_key]+1,pages-1].min }]])
    end
    def number_cell(id,value,min,max,step = nil,&apply)
      {:id=>id,:value=>value,:min=>min,:max=>max,:step=>step,:apply=>apply}
    end
    def capture(id)
      commit
      @capture = id
      @notice = 'Press shortcut; Backspace clears; Esc cancels.'
    end
    def text_input
      if @capture
        if Native.trigger?('escape')
          @capture = nil
        else
          chord = Native.capture
          if @capture == 'skip' && !chord
            chord = Native.modifiers.find { |v| Native.trigger?(v) }
          end
          if chord
            chord = '' if ['backspace','delete'].include?(chord)
            VXCheat.bind(@capture,chord)
            @capture = nil
            @notice = Storage.error || 'Shortcut saved'
          end
        end
        return
      end
      return unless @edit
      if Native.trigger?('escape')
        state[:search] = @edit[:original] if @edit[:id] == 'search'
        @edit = nil
        @notice = 'Edit cancelled'
      elsif Native.trigger?('tab')
        id = @edit[:id]
        index = @field_regions.index { |r| r[2] == id }
        commit
        if index && !@field_regions.empty?
          next_index = (index + (Native.down?('shift') ? -1 : 1)) % @field_regions.size
          @field_regions[next_index][1].call
        end
      elsif Native.trigger?('enter')
        id = @edit[:id]
        commit
        @enter_actions[id].call if @enter_actions[id]
      else
        @edit[:all] = true if Native.down?('ctrl') && Native.trigger?('a')
        if Native.down?('ctrl')
          Native.copy(@edit[:text]) if Native.trigger?('c') || Native.trigger?('x')
          if Native.trigger?('x')
            @edit[:text] = ''
            @edit[:cursor] = 0
            @edit[:all] = false
          end
          if Native.trigger?('v')
            @edit[:text] = '' if @edit[:all]
            @edit[:cursor] = 0 if @edit[:all]
            @edit[:all] = false
            Native.paste
          end
        end
        at = @edit[:cursor]
        if Native.repeat?('left') || Native.repeat?('right') || Native.trigger?('home') || Native.trigger?('end')
          at = [at-1,0].max if Native.repeat?('left')
          at = [at+1,@edit[:text].length].min if Native.repeat?('right')
          at = 0 if Native.trigger?('home')
          at = @edit[:text].length if Native.trigger?('end')
          @edit[:cursor], @edit[:all] = at, false
        end
        if Native.repeat?('backspace') || Native.repeat?('delete')
          if @edit[:all]
            @edit[:text], @edit[:cursor] = '', 0
          elsif Native.repeat?('backspace') && at > 0
            @edit[:text] = @edit[:text][0...at-1] + @edit[:text][at..-1].to_s
            @edit[:cursor] -= 1
          elsif Native.repeat?('delete')
            @edit[:text] = @edit[:text][0...at] + @edit[:text][at+1..-1].to_s
          end
          @edit[:all] = false
        end
        unless Native.text.empty?
          @edit[:text], @edit[:cursor] = '', 0 if @edit[:all]
          at = @edit[:cursor]
          @edit[:text] = (@edit[:text][0...at] + Native.text + @edit[:text][at..-1].to_s)[0,256]
          @edit[:cursor] = [at+Native.text.length,@edit[:text].length].min
          @edit[:all] = false
        end
        if @edit[:id] == 'search'
          state[:search] = @edit[:text]
          state[:page] = 0
        end
      end
    end
    def update
      if @native
        invalidate if Display.poll
        @mx, @my = Display.x, Display.y
        opacity = inside?([0,0,700,400]) ? 255 : 235
        Display.present(opacity) if @native_opacity != opacity
        @native_opacity = opacity
      else
        @mx = (Native.x - @sprite.x) / @scale
        @my = (Native.y - @sprite.y) / @scale
        @sprite.opacity = inside?([0,0,700,400]) ? 255 : 77
        @cursor.x, @cursor.y = Native.x, Native.y
        @cursor.visible = inside?([0,0,700,400])
      end
      hover = @regions.reverse.find { |r| inside?(r[0]) } || @text_regions.reverse.find { |r| inside?(r[0]) }
      hover_key = hover && hover[0]
      invalidate if @hover_key != hover_key
      @hover_key = hover_key
      was_editing = editing?
      previous_edit = @edit && [@edit[:id],@edit[:text].dup,@edit[:cursor],@edit[:all]]
      previous_capture = @capture
      text_input
      current_edit = @edit && [@edit[:id],@edit[:text],@edit[:cursor],@edit[:all]]
      invalidate if previous_edit != current_edit || previous_capture != @capture
      return if @disposed
      if !was_editing && (Native.trigger?('escape') || Native.trigger?(2))
        VXCheat.close
        return
      end
      if Native.trigger?(1) && !@capture
        invalidate
        @window_drag = [Display.screen_x,Display.screen_y] if @native && inside?([204,0,396,38])
        hit = @regions.reverse.find { |r| inside?(r[0]) }
        commit if @edit && (!hit || hit[2] != @edit[:id])
        hit ? hit[1].call : commit
      end
      return if @disposed
      if @window_drag
        if Native.down?(1)
          Display.move(Display.screen_x-@window_drag[0],Display.screen_y-@window_drag[1])
          @window_drag = [Display.screen_x,Display.screen_y]
        else
          @window_drag = nil
        end
      end
      if @drag
        Native.down?(1) ? drag_slider : @drag = nil
      end
      if @native && inside?([0,0,700,400]) && Native.down?('ctrl') && Native.wheel != 0
        amount = Native.wheel/120*5
        Storage.set('ui_size',[[Storage.number('ui_size',65,150)+amount,65].max,150].min.to_i)
        invalidate
      elsif @mx >= 204 && @mx <= 692
        previous_scroll = @scroll
        delta = -Native.wheel / 120.0 * 48
        delta += 200 if Native.trigger?('pagedown') && !editing?
        delta -= 200 if Native.trigger?('pageup') && !editing?
        @scroll = [[@scroll + delta,0].max,[@extent.to_i-328,0].max].min
        invalidate if previous_scroll != @scroll
      end
      stamp = [Storage.values.hash,Storage.error,Translator.message,@notice]
      invalidate if stamp != @data_stamp
      render if @dirty
    rescue StandardError => e
      @notice = e.message
      log_error(e)
      if @native
        Display.close
        @native = false
        @sprite.visible = true
        @notice = 'Display UI failed; using game rendering. See ui-error.log.'
      end
      render unless @disposed
    end
    def log_error(error)
      signature = [@panel_name,error.class.name,error.message,(error.backtrace || []).first]
      return if @last_logged_error == signature
      @last_logged_error = signature
      Dir.mkdir(Storage::DIRECTORY) unless File.directory?(Storage::DIRECTORY)
      File.open(Storage::DIRECTORY + '/ui-error.log','ab') do |file|
        file.write("#{Time.now} [#{@panel_name}] #{error.class}: #{error.message}\n#{(error.backtrace || []).join("\n")}\n")
      end
    rescue StandardError
    end
    def failed_panel
      section('This panel could not be drawn.')
      section(@failed_panel[1][0,65])
      section('Other panels and Ctrl+C remain available.')
      buttons([['Retry panel',proc { @failed_panel = nil; invalidate }]])
    end
    def draw_panel
      if @failed_panel && @failed_panel[0] == @panel_name
        failed_panel
        return
      end
      panel = VXCheat.panels.find { |p| p[0] == @panel_name }
      panel[1].call(self) if panel
    rescue StandardError => error
      @failed_panel = [@panel_name,"#{error.class}: #{error.message}"]
      log_error(error)
      @regions, @field_regions, @enter_actions = [], [], {}
      rect(204,38,496,332,BG)
      @flow = 42
      failed_panel
    end
    def render
      @regions = []
      @text_regions = []
      @field_regions, @enter_actions = [], {}
      @tooltip = nil
      @bitmap.clear unless @native
      style = [Storage.get('ui_size'),Storage.get('ui_text')]
      @native_metrics.clear if style != @native_style
      @native_style = style
      @sprite.opacity = @mx && inside?([0,0,700,400]) ? 255 : 77
      rect(0,0,700,400,BG)
      rect(0,0,200,400,CARD)
      @flow = 42
      draw_panel
      @extent = @flow - 42
      # Header/footer mask scrolling content.
      rect(201,0,499,38,BG)
      rect(201,370,499,30,BG)
      text(214,5,390,28,@panel_name)
      rect(610,5,56,25,PINK)
      text(610,5,56,25,'Reload',WHITE,1)
      region(610,5,56,25) { commit; @failed_panel = nil; @notice = 'Refreshed'; invalidate }
      # Keep the close button separate from scrolling content.
      rect(674,5,20,25,FIELD)
      text(674,5,20,25,'x',WHITE,1)
      region(674,5,20,25) { commit; VXCheat.close }
      y = 10
      VXCheat.panels.each do |name,draw|
        if name == 'Item' || name == 'Settings / Appearance'
          group = name == 'Item' ? 'Items' : 'Settings'
          text(14,y,176,22,(@nav_collapsed[group] ? '>  ' : 'v  ')+group,MUTED)
          region(7,y,185,22) { @nav_collapsed[group] = !@nav_collapsed[group] }
          y += 22
        end
        next if ['Item','Weapon','Armor'].include?(name) && @nav_collapsed['Items']
        next if name.start_with?('Settings / ') && @nav_collapsed['Settings']
        rect(7,y,185,24,BLUE) if name == @panel_name
        nested = (['Item','Weapon','Armor'].include?(name) || name.start_with?('Settings / '))
        text(nested ? 30 : 14,y,nested ? 160 : 176,24,name.sub('Settings / ',''))
        region(7,y,185,24) { select_panel(name) }
        y += 24
      end
      message = Storage.error || @tooltip || @notice || 'Ctrl+C: close | Click fields to edit | Wheel: scroll'
      text(212,373,480,24,message,MUTED)
      if @extent > 328
        rect(692,42,3,324,FIELD)
        h = [324*328/@extent,20].max
        y = 42 + (324-h)*@scroll/[@extent-328,1].max
        rect(692,y,3,h,MUTED)
        region(686,42,14,324) { commit; @scroll = [[(@my-42)/324.0*(@extent-328),0].max,@extent-328].min }
      end
      @data_stamp = [Storage.values.hash,Storage.error,Translator.message,@notice]
      if @native
        @native_opacity = @mx && inside?([0,0,700,400]) ? 255 : 235
        Display.present(@native_opacity)
      end
      @dirty = false
    end
  end
end
