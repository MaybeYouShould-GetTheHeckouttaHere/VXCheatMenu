# encoding: utf-8
module VXCheat
  module Storage
    DIRECTORY = './cheat-settings'
    DEFAULTS = {'no_clip'=>'0', 'no_encounters'=>'0', 'god_ids'=>'',
      'move_speed'=>'4', 'fixed_speed'=>'0', 'game_speed'=>'1.0', 'speed_scope'=>'all',
      'quick_save_slot'=>'1', 'quick_load_slot'=>'1', 'shortcut_speed'=>'5', 'skip_accelerate'=>'1',
      'translate_enabled'=>'0','translate_endpoint'=>'ezTransWeb','translate_method'=>'get',
      'translate_url'=>'http://localhost:5000/translate?text=${TEXT}', 'translate_body'=>'${TEXT}',
      'translate_chunk'=>'100','translate_maps'=>'1','translate_switches'=>'1','translate_variables'=>'1',
      'ui_renderer'=>'native','ui_size'=>'90','ui_text'=>'115'}
    class << self
      attr_reader :values, :locations, :error
      def load
        @values = DEFAULTS.dup
        @locations = []
        if File.file?(DIRECTORY + '/settings.ini')
          File.foreach(DIRECTORY + '/settings.ini') do |line|
            key, value = line.strip.split('=', 2)
            @values[key] = value if value && (DEFAULTS.key?(key) || key =~ /\Akey\.\w+\z/)
          end
        end
        if File.file?(DIRECTORY + '/locations.tsv')
          File.foreach(DIRECTORY + '/locations.tsv') do |line|
            parts = line.strip.split("\t")
            next unless parts.size == 5 && parts[0] =~ /\A(?:[a-f0-9]{2})*\z/i
            id, x, y, dir = parts[1..4].map { |v| Integer(v) }
            next unless id > 0 && x >= 0 && y >= 0 && [2,4,6,8].include?(dir)
            @locations << [[parts[0]].pack('H*').force_encoding('UTF-8'), id, x, y, dir]
          end
        end
      rescue StandardError => e
        @error = "Settings read failed: #{e.message}"
      end
      def get(key); @values[key]; end
      def bool(key); get(key) == '1'; end
      def number(key, min, max)
        v = Float(get(key)) rescue Float(DEFAULTS[key] || min)
        v = min unless v.finite?
        [[v, min].max, max].min
      end
      def set(key, value)
        return true if @values[key] == value.to_s
        @values[key] = value.to_s
        save
      end
      def atomic_write(name, text)
        Dir.mkdir(DIRECTORY) unless File.directory?(DIRECTORY)
        path = DIRECTORY + '/' + name
        File.open(path + '.tmp', 'wb') { |file| file.write(text) }
        # Windows rename with replacement, no interval with a missing settings file.
        move = Win32API.new('kernel32', 'MoveFileExW', 'PPI', 'I')
        a = (File.expand_path(path + '.tmp') + "\0").encode('UTF-16LE')
        b = (File.expand_path(path) + "\0").encode('UTF-16LE')
        raise 'Could not replace settings file' if move.call(a, b, 9) == 0
      end
      def save
        atomic_write('settings.ini', @values.keys.sort.map { |k| "#{k}=#{@values[k]}\n" }.join)
        @error = nil
        true
      rescue StandardError => e
        @error = "Settings write failed (session still usable): #{e.message}"
        false
      end
      def save_locations
        text = @locations.map { |v| ([v[0].unpack('H*')[0]] + v[1..4]).join("\t") }.join("\n")
        atomic_write('locations.tsv', text)
        @error = nil
      rescue StandardError => e
        @error = "Location write failed: #{e.message}"
      end
    end
    load
  end
end

module VXCheat
  module Names
    class << self
      def load
        @names = {}
        path = Storage::DIRECTORY + '/translations.tsv'
        return unless File.file?(path)
        File.open(path,'r:UTF-8') do |file|
          file.each_line do |line|
            category,id,name = line.chomp.split("\t",3)
            @names[[category,id.to_i]] = name if name && id =~ /\A\d+\z/
          end
        end
      rescue StandardError
        @names ||= {}
      end
      def get(category,id,fallback); @names.fetch([category,id],fallback); end
      def store(entries)
        entries.each { |category,id,name| @names[[category,id]] = name }
        text = @names.keys.sort.map { |key| (key + [@names[key].gsub(/[\r\n\t]/,' ')]).join("\t") }.join("\n")
        Storage.atomic_write('translations.tsv',text)
      end
      def map_path(id)
        path, visited = [], []
        while id && id != 0 && $data_mapinfos[id] && !visited.include?(id)
          visited << id
          info = $data_mapinfos[id]
          path.unshift(get('map',id,info.name))
          id = info.parent_id
        end
        path.join(' / ')
      end
    end
    load
  end
end
