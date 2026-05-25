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
| `ghcr.io/davidcozens/cpputest-freertos` (MIDDLE) | `cpputest@sha-18f19e1` | FreeRTOS-Kernel, Plus-TCP, lwIP, FatFs, Mbed TLS sources at `/opt/...` + `FREERTOS_*_PATH` / `LWIP_PATH` / `FATFS_PATH` / `MBEDTLS_DIR` env vars | Host-TDD of FreeRTOS adapters against fakes |
| `ghcr.io/davidcozens/cpputest-freertos-cross` (TOP) | `cpputest-freertos:sha-<same>` | `gcc-arm-none-eabi`, `gdb-multiarch` (aliased as `arm-none-eabi-gdb`), `qemu-system-arm`, `python3` + `behave==1.3.3` | Cross builds, on-QEMU runs, GDB attach, BDD scenarios that drive a QEMU target |

The TOP image FROMs the MIDDLE image at the same SHA tag; the publishing
workflow wires this automatically (see `.github/workflows/docker-publish.yml`).

## Pinned upstream sources (MIDDLE)

| Component | Repo | Ref | Commit SHA |
|---|---|---|---|
| FreeRTOS-Kernel | `FreeRTOS/FreeRTOS-Kernel` | tag `V11.1.0` | `dbf70559b27d39c1fdb68dfb9a32140b6a6777a0` |
| FreeRTOS-Plus-TCP | `FreeRTOS/FreeRTOS-Plus-TCP` | tag `V4.2.2` | `abcb94c8768532a6cae3c39ffe37602640992a28` |
| lwIP | `lwip-tcpip/lwip` (GitHub mirror of <https://savannah.nongnu.org/projects/lwip/>) | tag `STABLE-2_2_1_RELEASE` | `77dcd25a72509eb83f72b033d219b1d40cd8eb95` |
| FatFs (ChaN) | `abbrev/fatfs` (community Git mirror of <http://elm-chan.org/fsw/ff/>) | tag `R0.16` | `30ca13c62615df0d2e9104ab41256985b96590c1` |
| Mbed TLS | `Mbed-TLS/mbedtls` | tag `v3.6.2` (LTS) | `107ea89daaefb9867ea9121002fbbdf926780e98` |

FatFs is distributed by ChaN as zip tarballs only — there is no upstream Git
repo. We pull from the long-running community mirror `github.com/abbrev/fatfs`
which faithfully tags ChaN's official releases (R0.10 through R0.16 at the
time of writing). The SHA gate ensures a retagged mirror fails the build
loudly. Bump tag and SHA together when a new FatFs release lands.

Each `RUN git clone ...` is followed by a SHA gate (`[ "$(git rev-parse HEAD)" = "..." ]`)
so a moved upstream tag fails the build loudly rather than silently picking up
new code.

## Usage

```bash
docker pull ghcr.io/davidcozens/cpputest-freertos:latest         # MIDDLE
docker pull ghcr.io/davidcozens/cpputest-freertos-cross:latest   # TOP
```

Prefer SHA tags for reproducibility:

```bash
docker pull ghcr.io/davidcozens/cpputest-freertos:sha-<commit>
docker pull ghcr.io/davidcozens/cpputest-freertos-cross:sha-<commit>
```

Available tags appear on the package pages:
- [cpputest-freertos](https://github.com/davidcozens/CppUTestFreertosDocker/pkgs/container/cpputest-freertos)
- [cpputest-freertos-cross](https://github.com/davidcozens/CppUTestFreertosDocker/pkgs/container/cpputest-freertos-cross)

## Building locally

The MIDDLE image FROMs `cpputest:sha-18f19e1` directly:

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
pinned to MIDDLE's just-published `sha-<short>` tag.

## Updating

When bumping any upstream version:

1. Edit the relevant `*_TAG` and `*_SHA` ARGs in `dockerfile.host`.
2. Push to `main` — the workflow rebuilds and republishes both images.
3. Update the SHA tag in
   [solid-syslog `docs/containers.md`](https://github.com/DavidCozens/solid-syslog/blob/main/docs/containers.md)
   and the files it lists under "Files to update".

When the parent CppUTestDocker image moves on, also bump the `FROM` line in
`dockerfile.host`.
