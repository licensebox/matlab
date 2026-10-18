function github_ci()
% One licensed MATLAB process for matlab-actions/run-command on public CI.
% Fresh native Client per request; real shared server and persistence behavior.
  root=fileparts(fileparts(mfilename('fullpath')));
  previous=pwd;restore=onCleanup(@()cd(previous));cd(root);
  build_and_test();
  python=getenv('PYTHON');if isempty(python),python='python3';end
  protocol=getenv('LICENSEBOX_PROTOCOL_DIR');
  if isempty(protocol),protocol=fullfile(fileparts(root),'protocol');end
  assert(isfile(fullfile(protocol,'conformance','run.py')),'licensebox:ci','Missing shared protocol checkout');
  assert(isfile(fullfile(protocol,'conformance','mex_strings.py')),'licensebox:ci','Missing shared MEX regression');
  ipc=tempname;mkdir(ipc);log=fullfile(root,'build','matlab-conformance.log');
  args={python,fullfile(root,'test','ipc_driver.py'),ipc,protocol};
  command=javaArray('java.lang.String',numel(args));
  for i=1:numel(args),command(i)=java.lang.String(args{i});end
  builder=java.lang.ProcessBuilder(command);
  builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(log));
  try
    process=builder.start();
  catch failure
    rmdir(ipc,'s');rethrow(failure);
  end
  previousInput=getenv('LICENSEBOX_CONFORMANCE_INPUT');
  cleanup=onCleanup(@()stop_worker(process,ipc,previousInput));
  started=tic;requests=0;
  try
    while process.isAlive()
      assert(toc(started)<600,'licensebox:ci','MATLAB shared suite exceeded 600-second deadline');
      if isfile(fullfile(ipc,'ready.json'))
        pending=dir(fullfile(ipc,'*.request.json'));
        assert(numel(pending)<=1,'licensebox:ci','Unexpected concurrent adapter requests');
        if ~isempty(pending)
          request=fullfile(ipc,pending(1).name);
          processing=[request '.processing'];
          [claimed,message]=movefile(request,processing,'f');assert(claimed,'licensebox:ci','Cannot claim adapter request: %s',message);
          setenv('LICENSEBOX_CONFORMANCE_INPUT',processing);
          output=evalc('adapter()');
          answer=jsondecode(output);
          assert(isstruct(answer)&&isscalar(answer)&&isfield(answer,'ok')&&islogical(answer.ok)&&isscalar(answer.ok),'licensebox:ci','Malformed real adapter response');
          response=strrep(request,'.request.json','.response.json');
          delete(processing);
          write_atomic(response,output);
          requests=requests+1;
          if mod(requests,10)==0,fprintf('MATLAB adapter completed %d fresh-client requests\n',requests);end
        end
      end
      pause(.01);
    end
    status=process.exitValue();
    if isfile(log),fprintf('%s',fileread(log));end
    assert(status==0,'licensebox:ci','Shared suite driver failed (exit %d)',status);
    completed=fullfile(ipc,'finished.json');assert(isfile(completed),'licensebox:ci','Missing driver completion marker');
    result=jsondecode(fileread(completed));
    assert(isstruct(result)&&isfield(result,'ok')&&isequal(result.ok,true)&&isfield(result,'suites')&&result.suites==2&&isfield(result,'exit_code')&&result.exit_code==0,'licensebox:ci','Shared suites did not complete successfully');
    fprintf('PASS: single-session MATLAB CI (fresh clients, real persistence, 69 shared checks and MEX strings)\n');
  catch failure
    write_atomic(fullfile(ipc,'fatal'),failure.identifier);
    if isfile(log),fprintf('%s',fileread(log));end
    rethrow(failure);
  end
end
function write_atomic(path,value)
  temporary=[path '.tmp'];
  file=fopen(temporary,'w','n','UTF-8');assert(file>=0,'licensebox:ci','Cannot create adapter response');
  cleanup=onCleanup(@()fclose(file));fprintf(file,'%s',value);clear cleanup;
  [ok,message]=movefile(temporary,path,'f');assert(ok,'licensebox:ci','Cannot commit adapter response: %s',message);
end
function stop_worker(process,ipc,previousInput)
  if process.isAlive()
    process.destroy();
    for i=1:40,if ~process.isAlive(),break;end;pause(.05);end
    if process.isAlive(),process.destroyForcibly();end
  end
  setenv('LICENSEBOX_CONFORMANCE_INPUT',previousInput);
  if isfolder(ipc),rmdir(ipc,'s');end
end
