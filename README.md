# CppUTest FreeRTOS Docker

Two layered Docker images that extend
[CppUTestDocker](https://github.com/DavidCozens/CppUTestDocker) with FreeRTOS
upstream sources and (optionally) an ARM cross toolchain plus QEMU.

Used by [SolidSyslog](https://github.com/DavidCozens/solid-syslog) for
host-side TDD of `Platform/FreeRtos/` adapters and for cross-building
`Example/FreeRtos/` targets that run under QEMU emulation.

## Images

| Image | Built from | Adds | Use |
|---|---|---|---|
| `ghcr.io/cososo-ltd/cpputest-freertos` (MIDDLE) | `cpputest:latest`, pinned by digest | FreeRTOS-Kernel, Plus-TCP, Plus-FAT, lwIP, FatFs, LittleFS, Mbed TLS, wolfSSL, CMSIS_6 and CMSIS-FreeRTOS sources at `/opt/...` + `FREERTOS_*_PATH` / `LWIP_PATH` / `FATFS_PATH` / `LITTLEFS_PATH` / `MBEDTLS_DIR` / `WOLFSSL_SOURCE_DIR` / `CMSIS_PATH` / `CMSIS_FREERTOS_PATH` env vars | Host-TDD of FreeRTOS and CMSIS-RTOS2 adapters against fakes |
| `ghcr.io/cososo-ltd/cpputest-freertos-cross` (TOP) | `cpputest-freertos:sha-<same>` | `gcc-arm-none-eabi`, `gdb-multiarch` (aliased as `arm-none-eabi-gdb`), `qemu-system-arm`, `python3` + `behave==1.3.3` | Cross builds, on-QEMU runs, GDB attach, BDD scenarios that drive a QEMU target |

The TOP image FROMs the MIDDLE image at the same SHA tag; the publishing
workflow wires this automatically (see `.github/workflows/docker-publish.yml`).

## Pinned upstream sources (MIDDLE)

`dockerfile.host` is the record of what is pinned: each upstream has an
`ARG <NAME>_TAG` (or `_BRANCH`) and `ARG <NAME>_SHA` pair, and the tag and
commit are not repeated here, where they would only fall behind. The
components, and where each comes from:

| Component | Repo | Notes |
|---|---|---|
| FreeRTOS-Kernel | `FreeRTOS/FreeRTOS-Kernel` | release tag |
| FreeRTOS-Plus-TCP | `FreeRTOS/FreeRTOS-Plus-TCP` | release tag |
| FreeRTOS-Plus-FAT | `FreeRTOS/Lab-Project-FreeRTOS-FAT` | branch `main` at a pinned commit; a Labs project with no release tags |
| lwIP | `lwip-tcpip/lwip` (GitHub mirror of <https://savannah.nongnu.org/projects/lwip/>) | `STABLE-x_y_z_RELEASE` tag |
| FatFs (ChaN) | `abbrev/fatfs` (community Git mirror of <http://elm-chan.org/fsw/ff/>) | `R0.xx` tag |
| Mbed TLS | `Mbed-TLS/mbedtls` | release tag, LTS line |
| wolfSSL (source only, nothing built) | `wolfSSL/wolfssl` | `vx.y.z-stable` tag, matching the release the `cpputest` base image built its host libraries from |
| LittleFS | `littlefs-project/littlefs` | release tag |
| CMSIS_6 | `ARM-software/CMSIS_6` | release tag |
| CMSIS-FreeRTOS | `ARM-software/CMSIS-FreeRTOS` | release tag, on the same kernel minor as FreeRTOS-Kernel |

FatFs is distributed by ChaN as zip tarballs only — there is no upstream Git
repo. We pull from the long-running community mirror `github.com/abbrev/fatfs`
which faithfully tags ChaN's official releases. The SHA gate ensures a
retagged mirror fails the build loudly.

Each `RUN git clone ...` is followed by a SHA gate (`[ "$(git rev-parse HEAD)" = "..." ]`)
so a moved upstream tag fails the build loudly rather than silently picking up
new code.

## Keeping the pins current

[Renovate](https://docs.renovatebot.com/), installed on the organisation as
the Mend GitHub App, opens a pull request when an upstream publishes a patch
or minor release, moving the tag and the SHA together. It does the same for
the digest the `FROM` line of `dockerfile.host` pins the cpputest base at, and
for the SHA-pinned actions in the publishing workflow. The publishing workflow
builds both images on that pull request and smokes them (see below), so a
release that no longer clones, gates or compiles fails there. `renovate.json`
holds the configuration.

Renovate finds a pin by the `# renovate:` comment immediately above its pair:

```dockerfile
# renovate: datasource=git-tags packageName=https://github.com/Mbed-TLS/mbedtls.git
ARG MBEDTLS_TAG=v3.6.7
ARG MBEDTLS_SHA=068ff080b369adfac81509f9b57b2afabaf82dc5
```

The `cpputest` base is a pin of the same kind with no comment: `dockerfile.host`
names it as `cpputest:latest` and pins the digest, and Renovate's Dockerfile
manager opens the digest bump when `cpputest` publishes. Merging it rebuilds
both images on the new base, which is how a change there reaches them.

A pin without the comment is invisible to it, so a new upstream needs one.
The comment carries:

- `datasource`: `git-tags` for a pin on a release tag, `git-refs` for the
  Plus-FAT branch, whose updates move only the SHA. Both resolve an annotated
  tag to the commit it points at, which is the hash the `git rev-parse HEAD`
  gate compares.
- `packageName`: the clone URL.
- `versioning`, where the tag is not plain semver. Renovate's default reads a
  capital `V` prefix or a `-stable` suffix as a pre-release and then offers
  no updates at all, so FreeRTOS, wolfSSL, lwIP and FatFs each name a regex
  that ranks their own tag shape.

Three kinds of update do not open a pull request. They are listed on the
Dependency Dashboard issue instead, and open one only when ticked there:

- A major version of anything. Under SolidSyslog's support statement a new
  major is platform work, not a bump. A dashboard entry means no decision has
  been recorded yet; once the epic exists, a per-pin `allowedVersions` rule
  in `renovate.json` names it and the entry goes. Mbed TLS 4 is the first:
  the pin serves the 3.6 LTS line, and a second pin would serve 4.x.
- A FreeRTOS-Kernel or CMSIS-FreeRTOS minor. The wrapper is written against
  a kernel minor, so the two are approved together and the pins move in one
  commit; patches of either flow.
- Any wolfSSL update. The sources here must match the release the `cpputest`
  base image built its host libraries from, so the pin moves with the base
  image rather than ahead of it. `dockerfile.host` compares the two version
  headers, so a base bump onto a different wolfSSL release fails the build
  until the source pin follows.

One release shape cannot be ranked: a lettered FatFs bugfix such as `R0.15a`
has no numeric order Renovate can compare. `R0.16` to `R0.17` is found; an
`R0.16a` is a hand bump.

## What merges itself

A Renovate pull request whose `host` and `cross` checks pass, smokes included,
merges itself: `renovate.json` sets `automerge`, and branch protection on
`main` requires both checks, so GitHub's auto-merge waits for them. The
publish that follows sends solid-syslog its bump pull request, and that one is
merged by hand there. A cpputest publish therefore reaches solid-syslog
through here with nobody acting: Renovate moves the base digest, the pull
request merges itself, and both images republish.

Two kinds of pull request come to the maintainer instead, by assignment, which
is a GitHub notification:

- one whose checks fail - Renovate assigns an automerge pull request only then;
- a major of anything, which never merges itself. An upstream major is
  platform work, and a GitHub Action's major is where its inputs change, which
  a pull request cannot exercise for the login, push and notify steps that run
  only on `main`.

A publish that fails on `main` after a green pull request sends no event, so
no bump pull request opens. solid-syslog's weekly Image Drift workflow is the
alarm for that: it fails when a pin there lags this repository's `main` with
no bump pull request to carry it.

The pins held for Dependency Dashboard approval - the FreeRTOS-Kernel and
CMSIS-FreeRTOS minors, and wolfSSL - open a pull request only when ticked, and
it then merges itself like any other once green.

## The smoke

The publishing workflow builds each image into the runner's Docker and runs
its smoke inside it before anything is pushed, on pull requests and on `main`
alike. A smoke checks what a bump can change, not any project built on the
image.

`smoke/host/smoke.sh`, against MIDDLE:

- each upstream is where its environment variable points, and one translation
  unit compiles against it with the image's gcc, under the minimal
  configuration headers in `smoke/host/config/`;
- where the upstream's header carries a version, it is the release the
  `dockerfile.host` tag names: FreeRTOS-Kernel, lwIP, Mbed TLS (header and
  library), the wolfSSL sources, and LittleFS to major and minor, which is all
  its header holds.

The other trees are checked by the compile alone. The FreeRTOS-Plus-TCP header
lags its tag (`V4.4.1` at `V4.4.2`); FreeRTOS-Plus-FAT, FatFs, CMSIS_6 and
CMSIS-FreeRTOS carry no version that matches the tag. For all of them the SHA
gate in `dockerfile.host` is what proves the tree is the release.

`smoke/cross/smoke.sh`, against TOP:

- `arm-none-eabi-gcc` compiles the kernel, its Cortex-M3 port and the
  CMSIS-FreeRTOS wrapper over it, under `smoke/cross/config/`;
- `arm-none-eabi-gdb` and `qemu-system-arm` answer;
- Behave is the release `dockerfile.cross` pins.

Whether a project still compiles against a new release is that project's own
CI's question, asked by the bump pull request the publish sends it.

## Usage

```bash
docker pull ghcr.io/cososo-ltd/cpputest-freertos:latest         # MIDDLE
docker pull ghcr.io/cososo-ltd/cpputest-freertos-cross:latest   # TOP
```

Prefer SHA tags for reproducibility:

```bash
docker pull ghcr.io/cososo-ltd/cpputest-freertos:sha-<commit>
docker pull ghcr.io/cososo-ltd/cpputest-freertos-cross:sha-<commit>
```

Available tags appear on the package pages:
- [cpputest-freertos](https://github.com/cososo-ltd/CppUTestFreertosDocker/pkgs/container/cpputest-freertos)
- [cpputest-freertos-cross](https://github.com/cososo-ltd/CppUTestFreertosDocker/pkgs/container/cpputest-freertos-cross)

## Building locally

The MIDDLE image FROMs `cpputest:latest` at a pinned digest directly:

```bash
docker build -f dockerfile.host -t cpputest-freertos:local .
```

The TOP image FROMs the MIDDLE image — pass the local tag via `BASE_TAG`:

```bash
docker build -f dockerfile.cross --build-arg BASE_TAG=local \
    -t cpputest-freertos-cross:local .
```

## Publishing

GitHub Actions publishes both images to the GitHub Container Registry on each
push to `main`. The workflow runs MIDDLE first, then TOP with `BASE_TAG`
pinned to MIDDLE's just-published `sha-<short>` tag. TOP is built on pull
requests too, for its smoke: there MIDDLE's tag is not yet in the registry, so
the TOP job rebuilds MIDDLE from the cache into an OCI layout and builds on
that, and does the same on `main` so the base it smokes is the base it pushes.

Once both are pushed, the workflow sends an `image-published` event to
[solid-syslog](https://github.com/cososo-ltd/solid-syslog), whose Image Bump
workflow opens the pull request that moves every reference to both images onto
the new digests and runs CI on it. The event is sent with a token minted from
the release GitHub App for solid-syslog, from the `RELEASE_PLEASE_APP_ID` and
`RELEASE_PLEASE_PRIVATE_KEY` organisation secrets; the App itself is not
installed here.

## Updating

A bump normally needs nothing: see "What merges itself" above. CodeRabbit
skips a Renovate pull request (`.coderabbit.yaml`); if one needed a
hand-pushed change to build, ask for the review with a `@coderabbitai review`
comment. A hand bump, for a pin Renovate cannot rank, edits the `*_TAG` and
`*_SHA` ARGs in `dockerfile.host` together and goes through a pull request in
the same way.
