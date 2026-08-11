# Judge0 CE ARM64/cgroup-v2 project charter

This fork targets a reproducible Judge0 CE 1.13.1 build for ARM64 with cgroup v2 support, especially Apple Silicon development environments. It preserves the upstream HTTP API, Rails application, and database migrations.

## Security status

**Development only. Not security reviewed. Do not expose this service to untrusted users or the public internet.** Docker Desktop runs Linux in a VM, and `privileged` containers plus a writable cgroup mount do not by themselves establish a secure multi-tenant boundary. Promotion beyond a `-dev.N` image requires an independent isolation review and passing adversarial tests on every supported host.

## Immutable upstream inputs

- Judge0 CE v1.13.1: `ffd7a48cc6da86d6ac155ef10dbd67d02736070b` (GPLv3)
- Judge0 compilers v1.4.0 reference: `90fa29c444d10130e68a03a2ede2a946b8c7a8a7`
- isolate v2.2.1: `9c84554464d2aa9161a424e70af67f4210a12c45`
- ARM64 Ubuntu 20.04 image: `sha256:722ea796ac2d57eeb3627c58a582fc1acc58be51faf815e1bce1682ae5c092f7`

The isolate source patch in `patches/isolate/` supplies AArch64 syscall 443 (`quotactl_fd`) when the older Ubuntu 20.04 libc headers omit it. The definition is AArch64-only and does not replace a value supplied by newer headers.

The PoC intentionally provides only the existing Judge0 language records for C (GCC 9.2.0), C++ (GCC 9.2.0), and Python (3.8.1), mapped to Ubuntu's native ARM64 GCC 9 and Python 3.8 packages. These compatibility paths unblock API testing but are not byte-for-byte toolchain matches. The full release must build each advertised compiler/runtime version from pinned source archives and disable language records that are not installed.

## PoC commands

```sh
docker build --platform linux/arm64 -f Dockerfile.arm64-poc -t judge0-arm64:1.13.1-dev.1 .
docker compose -f compose.apple-silicon.yml run --rm --entrypoint /api/scripts/probe-cgroup-v2.sh workers
docker compose -f compose.apple-silicon.yml up -d
```

The cgroup probe is a gate: it verifies ARM64, a unified hierarchy, the `cpu`, `memory`, and `pids` controllers, and the ability to create and configure a child cgroup. A failure means Docker Desktop is not exposing enough functionality for this design; do not continue to sandbox tests until it is understood.

## Current Docker Desktop finding

The local Apple Silicon probe on 2026-08-11 reached the following result:

```text
PASS: ARM64 and cgroup v2 are visible
PASS: cpu, memory, and pids controllers are available
FAIL: cgroup hierarchy is read-only or delegation is unavailable
```

Inside the privileged worker, `findmnt` reports the cgroup2 mount as `rw`, but `/sys/fs/cgroup` is mode `0555`, the process is placed below `/docker/<container-id>`, and creating a child cgroup fails. In other words, the files are visible but Docker Desktop has not delegated a writable subtree to the container. This blocks reliable cgroup-backed CPU, memory, and process isolation with the current Compose design. Treat this as a failed security-capability gate, not as a test-suite failure to waive.

Next experiments should be isolated from the Judge0 application build: test explicit cgroup delegation in a Linux VM, a systemd-managed ARM64 Linux host, and any Docker Desktop configuration that changes cgroup namespace/delegation behavior. The full compiler matrix should wait until one of those environments passes this probe.

## Release gates

The first candidate is `ghcr.io/<organization>/judge0-arm64:1.13.1-dev.1`. Publishing is intentionally deferred until the organization name, provenance workflow, and registry permissions are configured.

Before `ghcr.io/<organization>/judge0:1.13.1-arm64-cgv2`, automated tests must cover:

- C and C++ compilation/linking, Python, and every other advertised runtime
- stdin and exact expected-output comparison
- non-zero exits and compilation errors
- CPU, wall-time, memory, and process limits
- infinite loops and fork bombs
- filesystem isolation and disabled networking
- concurrent submissions and server/worker restarts
- compatibility with standard Judge0 clients

Each test must assert Judge0 status IDs and response fields, not merely successful HTTP responses. Host-kernel and Docker Desktop versions belong in test evidence because isolation behavior is host-dependent.
