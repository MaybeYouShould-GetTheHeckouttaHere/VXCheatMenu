# encoding: utf-8
# Executed by RGSS3 from the generated Marshal archive.
vxcheat_engine_scripts = $RGSS_SCRIPTS
begin
require 'zlib' unless defined?(Zlib::Inflate)
load './cheat/original_path.rb'
$RGSS_SCRIPTS = if defined?(VXCHEAT_ORIGINAL_BYTES_FILE)
  File.open(VXCHEAT_ORIGINAL_BYTES_FILE, 'rb') { |file| Marshal.load(file) }
else
  load_data(VXCHEAT_ORIGINAL_SCRIPTS)
end
sources = $RGSS_SCRIPTS.map { |entry| Zlib::Inflate.inflate(entry[2]) }
main_index = sources.rindex { |source| source =~ /SceneManager\s*\.\s*run/ }
raise 'VXCheat: cannot locate VX Ace Main (SceneManager.run)' unless main_index
$RGSS_SCRIPTS.each_with_index do |entry, index|
  if index == main_index
    load './cheat/storage.rb'
    load './cheat/input.rb'
    load './cheat/display.rb'
    load './cheat/core.rb'
    load './cheat/ui.rb'
    load './cheat/translate.rb'
    Dir['./cheat/panels/*.rb'].sort.each { |path| load path }
  end
  entry[3] = sources[index]
  eval(sources[index].force_encoding('UTF-8'), TOPLEVEL_BINDING, sprintf('{%04d} %s', index, entry[1]))
end
rescue Exception => error
  unless ['RGSSReset','SystemExit'].include?(error.class.name)
    begin
      Dir.mkdir('./cheat-settings') unless File.directory?('./cheat-settings')
      File.open('./cheat-settings/startup-error.log','wb') do |file|
        file.write("#{error.class}: #{error.message}\n#{(error.backtrace || []).join("\n")}\n")
      end
    rescue Exception
    end
  end
  raise
ensure
  $RGSS_SCRIPTS = vxcheat_engine_scripts
end
