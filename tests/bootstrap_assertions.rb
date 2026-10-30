require 'zlib'
Dir.mkdir('cheat')
Dir.mkdir('cheat/panels')
File.write('cheat/original_path.rb', "VXCHEAT_ORIGINAL_SCRIPTS = 'Data/Scripts.rvdata2'\nVXCHEAT_ORIGINAL_BYTES_FILE = './cheat/original_scripts.rvdata2'\n")
File.write('cheat/panels/fixture.rb', '# intercepted module fixture')
$bootstrap_order=[]
scripts = [[1,'Before',Zlib::Deflate.deflate('$bootstrap_order << :before')],
           [2,'Main',Zlib::Deflate.deflate('$bootstrap_order << :main; SceneManager.run')]]
File.open('cheat/original_scripts.rvdata2','wb') { |file| Marshal.dump(scripts,file) }
$RGSS_SCRIPTS = [[999,'Engine bootstrap','']]
$expected_engine_scripts = $RGSS_SCRIPTS
class Dir
  def self.[](pattern); ['./cheat/panels/fixture.rb']; end
end
module SceneManager
  def self.run; $bootstrap_order << :run; end
end
module Kernel
  alias vxcheat_test_original_load load
  def load(path,*arguments)
    if path.end_with?('original_path.rb')
      # WASI cannot implement Kernel.load's realpath syscall on Windows.
      eval(File.read(path),TOPLEVEL_BINDING,path)
    elsif path.start_with?('./cheat/')
      $bootstrap_order << File.basename(path)
    else
      vxcheat_test_original_load(path,*arguments)
    end
  end
end
