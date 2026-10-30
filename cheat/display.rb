# encoding: utf-8
module VXCheat
  # Geometry is in physical desktop pixels, independent of Graphics.width/height.
  module Display
    @open = Win32API.new('./cheat/input.dll','UIOpen','III','I')
    @destroy = Win32API.new('./cheat/input.dll','UIDestroy','','I')
    @configure = Win32API.new('./cheat/input.dll','UIConfigure','II','I')
    @poll = Win32API.new('./cheat/input.dll','UIPoll','P','I')
    @move = Win32API.new('./cheat/input.dll','UIMove','II','I')
    @fill = Win32API.new('./cheat/input.dll','UIFill','IIIII','I')
    @text = Win32API.new('./cheat/input.dll','UIText','IIIIPII','I')
    @measure = Win32API.new('./cheat/input.dll','UIMeasure','PI','I')
    @present = Win32API.new('./cheat/input.dll','UIPresent','I','I')
    @geometry = "\0" * 28
    @strings = {}
    class << self
      attr_reader :x,:y,:screen_x,:screen_y,:width,:height
      def open
        return false if Storage.get('ui_renderer') == 'game' || !Native.window_handle
        @active = @open.call(Native.window_handle,Storage.number('ui_size',65,150).to_i,Storage.number('ui_text',90,150).to_i) != 0
        poll if @active
        !!@active
      rescue StandardError
        close
        false
      end
      def active?; !!@active; end
      def close
        @destroy.call if @active
        @active = false
        @strings.clear
      end
      def wide(text)
        value = text.to_s
        entry = @strings.delete(value) || (value + "\0").encode('UTF-16LE')
        @strings[value] = entry
        @strings.shift while @strings.size > 256
        entry
      end
      def color(value); value.red.to_i | (value.green.to_i << 8) | (value.blue.to_i << 16); end
      def poll
        @configure.call(Storage.number('ui_size',65,150).to_i,Storage.number('ui_text',90,150).to_i)
        result = @poll.call(@geometry)
        raise 'Display-resolution UI window is unavailable' if result < 0
        left,top,@width,@height,@screen_x,@screen_y,visible = @geometry.unpack('l7')
        @x = (@screen_x-left)*700.0/[@width,1].max
        @y = (@screen_y-top)*400.0/[@height,1].max
        result == 1
      end
      def move(dx,dy); @move.call(dx,dy); end
      def fill(x,y,w,h,value); @fill.call(x.to_i,y.to_i,w.to_i,h.to_i,color(value)); end
      def text(x,y,w,h,value,tint,align)
        @text.call(x.to_i,y.to_i,w.to_i,h.to_i,wide(value),color(tint),align)
      end
      def measure(value)
        bytes = wide(value)
        @measure.call(bytes,bytes.bytesize/2-1)
      end
      def present(opacity = 255)
        raise 'Could not present the display-resolution UI' if @present.call(opacity) == 0
      end
    end
  end
end
