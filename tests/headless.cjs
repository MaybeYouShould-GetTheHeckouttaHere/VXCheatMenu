// No game process or game assets. Ruby execution uses isolated RGSS API doubles.
const fs = require('node:fs');
const path = require('node:path');
const { WASI } = require('node:wasi');
const root = path.resolve(__dirname, '..');
const deps = path.join(root, '.validation/ruby/node_modules');
const { RubyVM } = require(path.join(deps, '@ruby/wasm-wasi/dist/cjs/vm.js'));
(async () => {
  const workspace = path.join(root, '.validation');
  const scratch = fs.mkdtempSync(path.join(workspace, 'headless-'));
  try {
    const wasi = new WASI({version:'preview1', returnOnExit:true, preopens:{'/test':scratch}});
    const module = await WebAssembly.compile(fs.readFileSync(path.join(deps,'@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm')));
    const {vm} = await RubyVM.instantiateModule({module, wasip1:wasi});
    const evaluate = (source, filename) => vm.eval(`eval('${Buffer.from(source).toString('base64')}'.unpack('m0')[0].force_encoding('UTF-8'), TOPLEVEL_BINDING, '${filename}')`);
    evaluate(fs.readFileSync(path.join(__dirname,'rgss_doubles.rb'),'utf8'),'rgss_doubles.rb');
    for (const filename of ['storage.rb','input.rb','display.rb','core.rb','ui.rb','translate.rb',...fs.readdirSync(path.join(root,'cheat/panels')).filter(p=>p.endsWith('.rb')).sort().map(p=>'panels/'+p)]) {
      evaluate(fs.readFileSync(path.join(root,'cheat',filename),'utf8'), filename);
    }
    evaluate(fs.readFileSync(path.join(__dirname,'headless_assertions.rb'),'utf8'),'headless_assertions.rb');
    // Export mock drawing commands so layout can be inspected without the game.
    const drawing = vm.eval(`require 'json'; VXCheat::Overlay.new.instance_variable_get(:@bitmap).operations.to_json`).toString();
    fs.writeFileSync(path.join(root,'.validation/general-drawing.json'),drawing);
    evaluate(fs.readFileSync(path.join(__dirname,'bootstrap_assertions.rb'),'utf8'),'bootstrap_assertions.rb');
    const bootstrap = fs.readFileSync(path.join(root,'cheat/bootstrap.rb'),'utf8');
    evaluate(bootstrap,'bootstrap.rb');
    vm.eval(`check($RGSS_SCRIPTS.equal?($expected_engine_scripts),'engine script list was not restored');
      check($bootstrap_order==[:before,'storage.rb','input.rb','display.rb','core.rb','ui.rb','translate.rb','fixture.rb',:main,:run],'bootstrap execution order is wrong')`);
    const archive = fs.readFileSync(path.join(root,'cheat/bootstrap.rvdata2')).toString('base64');
    vm.eval(`a=Marshal.load('${archive}'.unpack('m0')[0]); check(Zlib::Inflate.inflate(a[0][2])=='${Buffer.from(bootstrap).toString('base64')}'.unpack('m0')[0],'Ruby could not decode the generated scripts archive')`);
    vm.eval(`$VERBOSE=nil; File.open('cheat/original_scripts.rvdata2','wb') { |f| Marshal.dump([[1,'Main',Zlib::Deflate.deflate('SceneManager.run; raise "fixture startup error"')]],f) }`);
    try { evaluate(bootstrap,'bootstrap.rb'); throw new Error('expected startup fixture to fail'); }
    catch (error) { if (!String(error).includes('fixture startup error')) throw error; }
    vm.eval(`check(File.read('cheat-settings/startup-error.log').include?('fixture startup error'),'startup error was not logged'); check($RGSS_SCRIPTS.equal?($expected_engine_scripts),'engine script list lost after an error')`);
    console.log(`${vm.eval('$headless_checks').toString()} headless Ruby assertions passed; no game was launched.`);
  } finally {
    const resolved = fs.realpathSync(scratch);
    if (!resolved.startsWith(fs.realpathSync(workspace)+path.sep)) throw new Error('Unsafe scratch path');
    fs.rmSync(resolved,{recursive:true,force:true});
  }
})().catch(error => {console.error(error);process.exitCode=1;});
