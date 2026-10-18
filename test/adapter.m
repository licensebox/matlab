function adapter()
  input=getenv('LICENSEBOX_CONFORMANCE_INPUT');if isempty(input),input='/dev/stdin';end;raw=fileread(input);r=jsondecode(raw);
  original=regexp(raw,'"keys"\s*:\s*(\{[^}]*\})','tokens','once');if ~isempty(original),r.keys=original{1};end
  try
    v=run(r);if any(strcmp(r.op,{'modules','requests'}))&&isstruct(v),v=num2cell(v);end;a=struct();a.ok=true;a.value=v;
  catch e
    prefix='licensebox:';
    if strncmp(e.identifier,prefix,length(prefix)),a=struct('ok',false,'error',e.identifier(length(prefix)+1:end));else,rethrow(e);end
  end
  out=jsonencode(a);if any(strcmp(r.op,{'logout','record'})),out=strrep(out,'"value":[]','"value":null');end;fprintf('%s\n',out);
end
function v=run(r)
  switch r.op
    case 'derive',v=Licensebox.deriveBinding(r.product,r.source,r.raw_id);return;
    case 'native',v=Licensebox.nativeBinding(r.product);return;
    case 'verify',v=Licensebox.verifyLease(r.token,r.product,r.keys,r.now);return;
  end
  args={};if isfield(r,'ca_bundle'),args={'ca_bundle',r.ca_bundle};end
  c=Licensebox(r.product,r.keys,'server',r.server,'directory',r.directory,'version','conformance','clock',@()r.now,'machine_binding',@()r.binding,'on_sign_in',@(url,code)[],args{:});
  cleanup=onCleanup(@()c.close());
  switch r.op
    case 'lease',v=c.lease();
    case 'require',m='core';if isfield(r,'module'),m=r.module;end;v=c.require(m);
    case 'repeat',c.require('core');v=c.require('core');
    case 'status',v=c.status();
    case 'sign_in',v=c.signIn(3);
    case 'logout',v=c.logout();
    case 'modules',v=c.modules();
    case 'requests',v=c.requests();
    case 'request',v=c.requestAccess({'export'},'café – test');
    case 'access-link',v=c.accessLink();
    case 'record',c.record('export',true,.125);c.record('export',false,.025);v=[];
    otherwise,error('unknown operation');
  end
end
