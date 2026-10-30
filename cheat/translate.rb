# encoding: utf-8
module VXCheat
  module Translator
    TOKEN = '${TEXT}'
    @start = Win32API.new('./cheat/input.dll','TranslateStart','PPII','I')
    @status = Win32API.new('./cheat/input.dll','TranslateStatus','','I')
    @read = Win32API.new('./cheat/input.dll','TranslateRead','PI','I')
    @reset = Win32API.new('./cheat/input.dll','TranslateReset','','I')
    @message = 'Translation idle'
    class << self
      attr_reader :message
      def endpoint
        case Storage.get('translate_endpoint')
        when 'ezTransWeb'; ['get','http://localhost:5000/translate?text=${TEXT}',TOKEN]
        when 'ezTransServer'; ['post','http://localhost:8000',TOKEN]
        else; [Storage.get('translate_method'),Storage.get('translate_url'),Storage.get('translate_body')]
        end
      end
      def escape(text)
        text.encode('UTF-8').bytes.map { |b| (b>=65 && b<=90)||(b>=97 && b<=122)||(b>=48 && b<=57)||[45,46,95,126].include?(b) ? b.chr : sprintf('%%%02X',b) }.join
      end
      def start(test = false)
        raise 'Translation request already running' if @queue || @reset.call == 0
        @test, @translated = test, 0
        @queue = []
        if test
          @queue << ['test',0,'test']
        else
          raise 'Enable translation first' unless Storage.bool('translate_enabled')
          if Storage.bool('translate_maps')
            $data_mapinfos.keys.sort.each { |id| @queue << ['map',id,$data_mapinfos[id].name] }
          end
          [['switch','switches',$data_system.switches],['variable','variables',$data_system.variables]].each do |category,target,values|
            next unless Storage.bool('translate_'+target)
            (1...values.size).each { |id| @queue << [category,id,values[id]] unless values[id].to_s.empty? }
          end
        end
        kick
      rescue StandardError
        @queue = nil unless @pending
        raise
      end
      def kick
        if @queue.empty?
          @queue, @pending = nil, nil
          @message = @test ? 'Translation server is available' : "Translated #{@translated} names"
          return
        end
        method,pattern,body = endpoint
        @pending = []
        limit = Storage.number('translate_chunk',1,500).to_i
        while @pending.size < limit && !@queue.empty?
          candidate = @pending + [@queue.first]
          joined = candidate.map { |v| v[2].gsub(/[\r\n]/,' ') }.join("\n")
          break if method == 'get' && !@pending.empty? && pattern.gsub(TOKEN,escape(joined)).size > 1800
          @pending << @queue.shift
        end
        text = @pending.map { |v| v[2].gsub(/[\r\n]/,' ') }.join("\n")
        url = pattern.gsub(TOKEN,escape(text))
        payload = body.to_s.gsub(TOKEN,text).encode('UTF-8')
        wide = (url+"\0").encode('UTF-16LE')
        raise 'Translation request exceeds limits or the worker is busy' if @start.call(wide,payload,payload.bytesize,method == 'post' ? 1 : 0) == 0
        @message = "Translating... #{@translated} names complete"
      end
      def decode(text)
        return text unless text.start_with?('"') && text.end_with?('"')
        body = text[1...-1]
        body = body.gsub(/\\u(d[89ab][0-9a-f]{2})\\u(d[cdef][0-9a-f]{2})/i) { [$1.to_i(16),$2.to_i(16)].pack('v*').force_encoding('UTF-16LE').encode('UTF-8') }
        escapes = {'n'=>"\n",'r'=>"\r",'t'=>"\t",'b'=>"\b",'f'=>"\f",'"'=>'"','\\'=>'\\','/'=>'/'}
        body.gsub(/\\(u[0-9a-fA-F]{4}|[nrtbf"\\\/])/) { $1.start_with?('u') ? [$1[1..-1].to_i(16)].pack('U') : escapes[$1] }
      end
      def update
        return unless @pending
        status = @status.call
        return if status == 1 || status == 3
        raise 'Translation server unavailable or HTTP request failed' if status != 2
        buffer = "\0" * 524288
        length = @read.call(buffer,buffer.bytesize)
        raise 'Could not read translation response' if length < 0
        response = decode(buffer[0,length].force_encoding('UTF-8'))
        lines = response.split(/\r?\n/,-1)
        lines.pop if lines.size == @pending.size+1 && lines.last.empty?
        raise 'Translation response must contain one line per name' unless lines.size == @pending.size
        Names.store(@pending.each_with_index.map { |v,i| [v[0],v[1],lines[i]] }) unless @test
        @translated += @pending.size
        @pending = nil
        kick
      rescue StandardError => e
        @reset.call
        @queue, @pending = nil, nil
        @message = e.message
      end
    end
  end
end
