"""Candidate TinyTapeout A5A GPIO regression; must be validated in CI."""
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def two_impulses_and_kalman_updates(dut):
    async def tick(sample=0, io=0):
        dut.clk.value = 0
        dut.ui_in.value = sample
        dut.uio_in.value = io
        await Timer(10, unit="ns")
        dut.clk.value = 1
        await Timer(10, unit="ns")
        dut.clk.value = 0
        await Timer(1, unit="ns")

    dut.ena.value = 1
    dut.rst_n.value = 0
    for _ in range(10):
        await tick()
    dut.rst_n.value = 1
    await tick(0, 0)  # first byte after reset: DSP configuration
    for i in range(256):
        await tick(255 if i in (60, 180) else 0, 0x40 if i == 0 else 0)
    for _ in range(180):
        await tick()
    async def page(n):
        await tick(0, 0x80 | n)
        return int(dut.uo_out.value)
    assert await page(8) == 2, 'Unexpected detection count'
    assert await page(9) == 2, 'Unexpected update count'
    assert await page(2) == 180, 'Unexpected last detected bin'
    assert await page(3) == 0, 'Unexpected bin high byte'
    assert await page(10) == 0, 'Overflow detected'
    assert int(dut.uio_oe.value) == 0
    assert int(dut.uio_out.value) == 0
