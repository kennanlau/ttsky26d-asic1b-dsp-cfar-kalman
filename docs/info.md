# ASIC-1B — integrated sample conditioning, detection and measurement update

## How it works

ASIC-1B integrates an 8-bit sample conditioning DSP (FIR/IIR configurations), a streaming one-dimensional CFAR detector, detection extraction, and a signed Q4.6 scalar Kalman **measurement update**. The design is a research demonstrator, not a complete radar tracker: there is no automatic target association, state prediction, dense-event queueing, or backpressure support. This wrapper supports a maximum 512-bin profile index and flags overflow.

## Pin protocol (qualified A5A wrapper)

- `ui_in[7:0]`: one unsigned sample is consumed every clock, **including during diagnostic reads**. The first input byte after reset is consumed as DSP configuration (mode/scale).
- `uio_in[2:0]`: CFAR mode on the SOP cycle; `uio_in[5:3]`: CFAR alpha on SOP; `uio_in[6]`: SOP strobe (one cycle).
- `uio_in[7] = 0`: `uo_out[7:0]` returns packed CFAR status; `uio_in[7] = 1`: diagnostic selection via `uio_in[3:0]`.
- Diagnostic pages: `0` processed DSP byte; `1` CFAR byte; `2` detected-bin low; `3` detected-bin high bit; `4/5` signed Q4.6 Kalman state low/high; `6/7` Q4.6 variance low/high; `8` detection count; `9` update count; `10` overflow flags (`bit0` event overflow, `bit1` profile overflow).
- `uio_out[7:0] = 0` and `uio_oe[7:0] = 0`: bidirectional pins are inputs only.

## How to test

Assert reset (`rst_n=0`) for several clocks, release reset, send configuration byte `0`, strobe SOP once using `uio_in[6]`, then send a 256-sample profile with impulses at indices 60 and 180. Keep driving samples while waiting for updates; do not exceed the supported bin range. With `uio_in[7]=1`, read diagnostic page 8 (detection count 2), page 9 (update count 2), page 2 (last detection bin 180), page 3 (high bit 0), and page 10 (no overflow). The original RTL and post-route gate-level pin contract were qualified separately; the proposed GitHub Actions Cocotb test has not yet been run.

## External hardware

No external hardware is required for simulation. Fabricated chip testing requires a TinyTapeout carrier/dev board and suitable interface hardware; physical silicon has not been received or qualified.

## Provenance

DSP, CFAR, and Kalman components are derived from three independently pinned open-source projects. See `third_party/UPSTREAM_PROVENANCE.md`; release approval was provided by the project submitter; third-party license texts and source provenance are included.
