# Validation — 2026-10-18

PASS: existing MATLAB R2025b runtime on Linux x86-64; real GCC MEX compilation, 100-client creation/close, closed-client rejection, terminal-NUL native-ID normalization, embedded-NUL rejection, and all 69 shared protocol conformance checks. The protocol adapter uses a private temporary input file because MATLAB batch mode closes stdin. No runtime activation or account settings were changed.

The C core was built as a shared library from the public SDK checkout. Test keys, times, identities and loopback server data are synthetic. Linux x86-64 only; other OS/runtime paths are unvalidated. No remote release or registry publication is performed by these scripts.

PASS: `matlab -batch "addpath('ci');github_ci()"` with actual R2025b: MEX build,
installed executable-package consumer, lifecycle checks, unchanged 69-case suite,
and shared `mex_strings.py` regression. Exact escaped-NUL JSON reaches MATLAB's
real JSON parser and MEX; no byte-framing substitution is required on this runtime.
Single-session CI validates fresh clients/persistence within one MATLAB process;
the earlier local batch adapter validated a fresh MATLAB OS process per request.
