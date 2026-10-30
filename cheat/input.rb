# encoding: utf-8
module VXCheat
  module Native
    KEY_NAMES = {'backspace'=>8, 'tab'=>9, 'enter'=>13, 'shift'=>16, 'ctrl'=>17,
      'alt'=>18, 'escape'=>27, 'space'=>32, 'pageup'=>33, 'pagedown'=>34,
      'end'=>35, 'home'=>36, 'left'=>37, 'up'=>38, 'right'=>39, 'down'=>40,
      'delete'=>46, '['=>219, ']'=>221, '-'=>189, '='=>187}
    ('a'..'z').each { |key| KEY_NAMES[key] = key.upcase.ord }
    ('0'..'9').each { |key| KEY_NAMES[key] = key.ord }
    12.times { |i| KEY_NAMES["f#{i + 1}"] = 112 + i }
    KEY_CODES = ([1,2] + KEY_NAMES.values).uniq.freeze
    @keyboard = Win32API.new('./cheat/input.dll', 'Keyboard', 'P', 'I')
    @key_buffer = "\0" * 256
    @cursor = Win32API.new('user32', 'GetCursorPos', 'P', 'I')
    @client = Win32API.new('user32', 'ScreenToClient', 'IP', 'I')
    @rect = Win32API.new('user32', 'GetClientRect', 'IP', 'I')
    @foreground = Win32API.new('user32', 'GetForegroundWindow', '', 'I')
    @active_window = Win32API.new('user32', 'GetActiveWindow', '', 'I')
    @is_window = Win32API.new('user32', 'IsWindow', 'I', 'I')
    @attach = Win32API.new('./cheat/input.dll', 'Attach', 'I', 'I')
    @enable = Win32API.new('./cheat/input.dll', 'Enable', 'I', 'I')
    @wheel_api = Win32API.new('./cheat/input.dll', 'Wheel', '', 'I')
    @char = Win32API.new('./cheat/input.dll', 'Character', '', 'I')
    @unicode = Win32API.new('./cheat/input.dll', 'UnicodeWindow', '', 'I')
    @paste = Win32API.new('./cheat/input.dll', 'Paste', '', 'I')
    @copy = Win32API.new('./cheat/input.dll', 'Copy', 'PI', 'I')
    @down, @old, @held = {}, {}, {}
    class << self
      attr_reader :x, :y, :wheel, :text
      def window_handle; @hwnd; end
      def initialize_window
        @hwnd = @active_window.call
        raise 'Could not attach mouse input to the game window' if @hwnd == 0 || @attach.call(@hwnd) == 0
        @unicode_window = @unicode.call != 0
      end
      def enable(value); @enable.call(value ? 1 : 0); end
      def paste; @paste.call; end
      def copy(text)
        bytes = text.encode('UTF-16LE')
        @copy.call(bytes,bytes.bytesize)
      end
      def update
        initialize_window unless @hwnd && @is_window.call(@hwnd) != 0
        @focused = @foreground.call == @hwnd
        @old = @down
        @down = {}
        @keyboard.call(@key_buffer) if @focused
        KEY_CODES.each do |code|
          @down[code] = @focused && @key_buffer.getbyte(code) != 0
          @held[code] = @down[code] ? (@held[code] || 0) + 1 : 0
        end
        point, rect = [0,0].pack('ll'), [0,0,0,0].pack('llll')
        @cursor.call(point)
        @client.call(@hwnd, point)
        @rect.call(@hwnd, rect)
        px, py = point.unpack('ll')
        r = rect.unpack('llll')
        @x = px * Graphics.width.to_f / [r[2],1].max
        @y = py * Graphics.height.to_f / [r[3],1].max
        @wheel = @focused ? @wheel_api.call : 0
        chars = []
        256.times do
          ch = @char.call
          break if ch == 0
          chars << ch if ch >= 32 && ch != 127
        end
        @text = if chars.empty?
          ''
        elsif @unicode_window
          chars.pack('v*').force_encoding('UTF-16LE').encode('UTF-8', :invalid=>:replace, :undef=>:replace)
        else
          chars.pack('C*').force_encoding(Encoding.find('locale')).encode('UTF-8', :invalid=>:replace, :undef=>:replace)
        end
        @text = '' unless @focused
      end
      def code(key); key.is_a?(Integer) ? key : KEY_NAMES[key.to_s]; end
      def down?(key); !!@down[code(key)]; end
      def trigger?(key); down?(key) && !@old[code(key)]; end
      def repeat?(key)
        count = @held[code(key)] || 0
        count == 1 || (count >= 24 && count % 4 == 0)
      end
      def modifiers
        ['ctrl','alt','shift'].select { |v| down?(v) }
      end
      def chord?(binding)
        keys = binding.to_s.split(' ')
        return false if keys.empty?
        key = keys.last
        modifiers.sort == keys[0...-1].sort && trigger?(key)
      end
      def capture
        key = KEY_NAMES.keys.find { |v| !['ctrl','alt','shift'].include?(v) && trigger?(v) }
        key ? (modifiers + [key]).join(' ') : nil
      end
    end
    enable(false)
  end
end
