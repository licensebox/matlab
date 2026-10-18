function lifetime()
 d=tempname();mkdir(d);
 raw='12345678123456789abc1234567890ab';
 expected=Licensebox.deriveBinding('demo','linux-machine-id',raw);
 assert(strcmp(expected,Licensebox.deriveBinding('demo','linux-machine-id',[raw char(0)])));
 try,Licensebox.deriveBinding('demo','linux-machine-id',[raw char(0) 'extra']);error('embedded NUL accepted');catch e,assert(strcmp(e.identifier,'licensebox:identity_unavailable'));end
 for i=1:100,c=Licensebox('demo',struct('test_key','A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg'),'directory',d);c.close();end
 c=Licensebox('demo',struct('test_key','A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg'),'directory',d);c.close();
 try,c.status();error('closed client accepted');catch e,assert(strcmp(e.identifier,'licensebox:closed'));end
end
