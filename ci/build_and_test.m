function build_and_test()
% Build and validate in this MATLAB process; never starts another runtime.
  root=fileparts(fileparts(mfilename('fullpath')));
  previous=pwd;restore=onCleanup(@()cd(previous));cd(root);
  include=getenv('LICENSEBOX_INCLUDE_DIR');library=getenv('LICENSEBOX_LIB_DIR');
  assert(~isempty(include)&&isfolder(include),'licensebox:ci','LICENSEBOX_INCLUDE_DIR is required');
  assert(~isempty(library)&&isfolder(library),'licensebox:ci','LICENSEBOX_LIB_DIR is required');
  if ~isfolder('build'),mkdir('build');end
  mex(['-I' include],['-L' library],'-llicensebox','src/licensebox_mex.c','-outdir','build');
  addpath(fullfile(root,'src'),fullfile(root,'build'),fullfile(root,'test'));
  lifetime();
  % Package only runnable MATLAB/MEX executables and LICENSE.
  % No C source, tests, CI scripts, documentation or private files are included.
  if ~isfolder('build/package'),mkdir('build/package');end
  copyfile('src/Licensebox.m','build/package/Licensebox.m');
  copyfile(['build/licensebox_mex.' mexext],['build/package/licensebox_mex.' mexext]);
  copyfile('LICENSE','build/package/LICENSE');
  assert(strcmp(mexext,'mexa64'),'licensebox:ci','Only Linux x86-64 packaging has been validated');
  [code,output]=system('tar -czf build/licensebox-matlab-0.1.0.tar.gz -C build/package Licensebox.m licensebox_mex.mexa64 LICENSE');
  assert(code==0,'licensebox:ci','SDK executable package creation failed: %s',output);
  installed_consumer(root);
end
function installed_consumer(root)
  destination=tempname;mkdir(destination);
  cleanup=onCleanup(@()restore_source(root,destination));
  untar(fullfile(root,'build','licensebox-matlab-0.1.0.tar.gz'),destination);
  clear Licensebox licensebox_mex;
  rmpath(fullfile(root,'src'),fullfile(root,'build'));
  addpath(destination,'-begin');
  assert(strcmp(which('Licensebox'),fullfile(destination,'Licensebox.m')),'licensebox:ci','Consumer resolved checkout instead of installed SDK');
  assert(strcmp(which('licensebox_mex'),fullfile(destination,['licensebox_mex.' mexext])),'licensebox:ci','Consumer resolved an uninstalled MEX');
  lifetime();
  value=Licensebox.nativeBinding('demo');assert(ischar(value));
  fprintf('PASS: installed MATLAB executable package consumer and native helper\n');
end
function restore_source(root,destination)
  clear Licensebox licensebox_mex;
  if contains(path,[destination pathsep])||endsWith(path,destination),rmpath(destination);end
  addpath(fullfile(root,'src'),fullfile(root,'build'));
  if isfolder(destination),rmdir(destination,'s');end
end
