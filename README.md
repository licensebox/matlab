# Licensebox for MATLAB

Application licensing SDK by [Vijai Kumar](https://meshing.engineer). MIT, 2026.
Uses the maintained Licensebox C core **>=0.3.0** for HTTPS, pure Ed25519 verification, native machine identity, persistence, activation, offline access, policy refusals and bounded usage collection. No licensing server or administration credentials are included.

## Build and install

MATLAB with MEX and a C compiler on a licensed runner. A GNU Octave pass does not validate MATLAB.
Build/install the public [C core](https://github.com/licensebox/c) as a shared library first. Export `LICENSEBOX_LIB_DIR` (directory containing liblicensebox.so), `LICENSEBOX_INCLUDE_DIR` (public headers), and `LD_LIBRARY_PATH`. `LICENSEBOX_LIBRARY` may identify the library path; scripts derive its containing directory when supplied. Linked bindings resolve liblicensebox.so through the native dynamic loader, so use a compatible library basename. CI uses only a disposable Ubuntu runner; ci/setup.sh is not a workstation installer.

```sh
bash ci/setup.sh
bash ci/test.sh
python3 ../protocol/conformance/run.py --adapter bash ci/adapter.sh
```

`ci/test.sh` builds real language code and runs repeated allocation/close checks, then creates or installs the language package. The adapter is test-only and supplies synthetic clock/binding callbacks. It is not a production command-line bypass.

## Use

```
addpath('src'); addpath('build');
c = Licensebox('your-product', '{"signing-key-id":"PUBLIC_BASE64URL_KEY"}', ...
              'version', '1.0', 'on_sign_in', @(url,code) fprintf('%s %s\n',url,code));
cleanup = onCleanup(@() c.close());
c.require('core'); % Check before opening user files.
```

Explicitly sign in using the sign-in method when the user chooses to activate. Retain one client per process and close it deterministically. A protected call renews silently with a short bound; verified unexpired offline access is allowed only for eligible transport/server failures. Expiry returns offline and does not automatically activate. Explicit policy refusals persist and block cached access. Native identity is never replaced with random, hostname or network identifiers.

## API

`lease`, `require`, `status`, `signIn`, `logout`, `modules`, `requests`, `requestAccess`, `accessLink`, `record`; static `deriveBinding`, `nativeBinding`, `verifyLease`. Verification keys may be supplied as a JSON object string to preserve IDs that are not valid struct field names.

Constructor options include version, server, directory and optional ca_bundle. TLS certificate and hostname verification stay enabled. The sign-in callback receives the verification URL and user code. Clock, machine binding and cancellation are **typed trusted application callbacks**, not JSON option overrides or end-user settings. Callback state stays alive for the native client's lifetime. Exceptions are contained at the FFI boundary and reported after native execution. Callbacks must not reenter the client; the wrapper rejects reentry. Calls and error inspection are serialized; do not move language runtime handles between unsupported threads.

Access links, leases and private device codes are credentials; avoid logs. Keep public verification keys in the application and installation private keys local. Collect fixed-command usage only; never filenames, arguments or file data.

## Validation

Validated locally on Linux x86-64 with the existing MATLAB R2025b runtime: actual MEX build, repeated client lifecycle, native identity helpers, NUL normalization/rejection regressions, and all 69 shared protocol conformance checks. Other MATLAB releases and operating systems remain unvalidated. See VALIDATION.md.

The exact public protocol pin is protocol-lock.json; native-version.txt records the minimum C release. Follow [the shared contract](https://github.com/licensebox/protocol) before changing licensing behavior. Administration remains in the Go CLI.

## Public MATLAB Actions CI

Public GitHub runners can use `matlab-actions/setup-matlab@v3` (R2025b) and
`matlab-actions/run-command@v3` with `command: cd('sdk'); addpath('ci'); github_ci()`.
Provide `LICENSEBOX_INCLUDE_DIR`, `LICENSEBOX_LIB_DIR`, `LD_LIBRARY_PATH`, and an
adjacent shared protocol checkout (or set `LICENSEBOX_PROTOCOL_DIR`). `PYTHON`
may select a Python interpreter with the protocol's cryptography dependency.

`github_ci` builds the real MEX, runs lifecycle/NUL checks, creates a Linux
executable SDK package containing only `Licensebox.m`, `licensebox_mex.mexa64`
and `LICENSE`, and verifies a consumer installed from that package. It then runs
the unchanged shared 69-case suite and MEX string regressions in one licensed
MATLAB session. A test-only Python adapter transports original JSON through a
private temporary directory; MATLAB calls the actual `adapter()` and creates and
closes a native client for each request. The transport neither implements nor
substitutes licensing decisions. Malformed messages, timeouts, worker failures,
or failed suite assertions fail CI; IPC state is cleaned up on completion.

This public-runner path validates fresh clients and file persistence within one
MATLAB OS process. The separate local `ci/adapter.sh` path starts a new MATLAB
process for each request; that path also passed all 69 cases on the existing
R2025b installation. The Actions entrypoint does not start nested MATLAB
processes or modify runtime activation, accounts or licenses.

## Optional explicit heartbeat

Use `client.heartbeat('core')` for an explicit bounded renewal/checkpoint. The mandatory module must be nonempty. The result contains `lease` (the complete verified lease, preserving optional signed `heartbeat.interval_seconds`/`grace_seconds`) and `online` (whether this check renewed successfully online). Every invocation attempts renewal, including after a cached `Require`; it never starts interactive activation or transfers a seat. Eligible outages may return `online=false` only while the last verified signed lease remains unexpired. Refusals, missing modules and expired offline access remain errors.

Default Client/Lease/Require behavior is unchanged. No timer, task, thread or background heartbeat starts automatically. The application owns event-loop scheduling/checkpoints on the language runtime thread, and safe cancellation of protected work on refusal or the last verified expiry deadline. A failed check cannot extend that deadline. This is especially important for MATLAB, Wolfram/JLink and other runtimes whose callbacks must stay on their owning thread. The matching native C heartbeat API/contract is required.

Validate the feature against the candidate native core with `python3 ../protocol/conformance/heartbeat.py --adapter bash ci/adapter.sh` in addition to the existing full shared suite.
