classdef Licensebox < handle
  properties (Access=private)
    nativeHandle
  end
  methods
    function self=Licensebox(product,keys,varargin)
      p=inputParser;
      addParameter(p,'version','');addParameter(p,'server','');addParameter(p,'directory','');addParameter(p,'ca_bundle','');
      addParameter(p,'on_sign_in',[]);addParameter(p,'clock',[]);addParameter(p,'machine_binding',[]);addParameter(p,'cancelled',[]);
      parse(p,varargin{:});v=p.Results;options=struct('product',product,'keys',keys,'version',v.version);
      names={'server','directory','ca_bundle'};for i=1:numel(names),n=names{i};if ~isempty(v.(n)),options.(n)=v.(n);end,end
      callbacks={v.on_sign_in,v.clock,v.machine_binding,v.cancelled};
      for i=1:4,if ~isempty(callbacks{i})&&~isa(callbacks{i},'function_handle'),error('licensebox:invalid_argument','Callbacks must be function handles');end,end
      if ischar(keys),keyJSON=keys;else,keyJSON=jsonencode(keys);end
      options=rmfield(options,'keys');encoded=jsonencode(options);encoded=[encoded(1:end-1) ',"keys":' keyJSON '}'];
      self.nativeHandle=licensebox_mex('create',encoded,callbacks);
    end
    function close(self)
      if ~isempty(self.nativeHandle),ignored=licensebox_mex('close',self.nativeHandle);self.nativeHandle=[];end
    end
    function delete(self),self.close();end
    function v=lease(self),v=self.call('lease',struct());end
    function v=require(self,module),v=self.call('require',struct('module',module));end
    function v=status(self),v=self.call('status',struct());end
    function v=signIn(self,timeout),if nargin<2,timeout=0;end;v=self.call('sign_in',struct('timeout',timeout));end
    function v=logout(self),v=self.call('logout',struct());end
    function v=modules(self),v=self.call('modules',struct());end
    function v=requests(self),v=self.call('requests',struct());end
    function v=requestAccess(self,names,note),if nargin<3,note='';end;v=self.call('request',struct('modules',{names},'note',note));end
    function v=accessLink(self),v=self.call('access-link',struct());end
    function v=record(self,command,success,elapsed),v=self.call('record',struct('command',command,'success',logical(success),'elapsed',elapsed));end
  end
  methods (Access=private)
    function v=call(self,operation,args)
      if isempty(self.nativeHandle),error('licensebox:closed','Client is closed');end
      v=jsondecode(licensebox_mex('call',self.nativeHandle,operation,jsonencode(args)));
    end
  end
  methods (Static)
    function v=deriveBinding(product,source,raw),v=licensebox_mex('derive',product,source,raw);end
    function v=nativeBinding(product),v=licensebox_mex('native',product);end
    function v=verifyLease(token,product,keys,now),if ischar(keys),keyJSON=keys;else,keyJSON=jsonencode(keys);end;v=jsondecode(licensebox_mex('verify',token,product,keyJSON,now));end
  end
end
