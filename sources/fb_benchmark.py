#!/usr/bin/env python3
"""
fb_benchmark.py - de-risk the v2 pure-Python framebuffer backend.

Runs ON THE PAGER. Verifies UI_TAKEOVER + mmap(/dev/fb0) and measures the
pure-Python render throughput that the new pagerctl.py backend will rely on.

Native fb: 222x480 portrait, RGB565 (16bpp), stride 444 bytes.
Takes over the display briefly, draws test patterns, prints timings, releases.
Stdlib only (python3-base): mmap, struct, time, os, subprocess.
"""
import mmap, os, struct, subprocess, sys, time

W, H, BPP = 222, 480, 2
STRIDE = 444                      # bytes per row (from /sys/class/graphics/fb0/stride)
FB_SIZE = STRIDE * H              # 213120
FB = "/dev/fb0"


def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def le16(v):
    return struct.pack("<H", v & 0xFFFF)


def takeover():
    subprocess.run(["UI_TAKEOVER"], check=False)


def release():
    subprocess.run(["UI_RELEASE"], check=False)


def main():
    print(f"fb size expected {FB_SIZE} bytes ({W}x{H}, stride {STRIDE})")
    takeover()
    time.sleep(0.2)
    try:
        fd = os.open(FB, os.O_RDWR)
    except OSError as e:
        print("open /dev/fb0 FAILED:", e)
        release(); return 1
    try:
        mm = mmap.mmap(fd, FB_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
    except Exception as e:
        print("mmap FAILED:", e)
        os.close(fd); release(); return 1

    results = {}

    # --- 1) full-frame solid fill (upper bound for a 'flip'/clear via memcpy) ---
    # Build a full native frame as a bytes blob, then write in one slice assignment.
    row_blue = le16(rgb565(0, 0, 255)) * W + b"\x00" * (STRIDE - W * BPP)
    frame_blue = row_blue * H
    N = 60
    t0 = time.monotonic()
    for _ in range(N):
        mm[0:FB_SIZE] = frame_blue
    dt = time.monotonic() - t0
    results["full_frame_memcpy_fps"] = N / dt

    # --- 2) build a frame pixel-by-pixel in a bytearray (worst case: per-pixel py) ---
    N2 = 5
    t0 = time.monotonic()
    for _ in range(N2):
        buf = bytearray(FB_SIZE)
        px = le16(rgb565(255, 128, 0))
        for y in range(H):
            base = y * STRIDE
            for x in range(W):
                o = base + x * BPP
                buf[o:o + 2] = px
        mm[0:FB_SIZE] = buf
    dt = time.monotonic() - t0
    results["per_pixel_python_fps"] = N2 / dt

    # --- 3) blit a pre-rendered 96x96 RGB565 sprite blob (row-wise memcpy) ---
    SW = SH = 96
    sprite = (le16(rgb565(0, 220, 120)) * SW) * SH   # pre-rendered blob, native-oriented
    dstx, dsty = 60, 180
    N3 = 200
    t0 = time.monotonic()
    for _ in range(N3):
        for row in range(SH):
            dst = (dsty + row) * STRIDE + dstx * BPP
            src = row * SW * BPP
            mm[dst:dst + SW * BPP] = sprite[src:src + SW * BPP]
    dt = time.monotonic() - t0
    results["sprite96_blits_per_sec"] = N3 / dt

    # --- leave a visible pattern so the user confirms it rendered ---
    mm[0:FB_SIZE] = frame_blue
    bar_h = H // 4
    for i, c in enumerate((rgb565(255,0,0), rgb565(0,255,0), rgb565(255,255,0), rgb565(255,255,255))):
        row = le16(c) * W + b"\x00" * (STRIDE - W * BPP)
        for y in range(i * bar_h, (i + 1) * bar_h):
            mm[y * STRIDE:y * STRIDE + len(row)] = row
    for row in range(SH):
        dst = (180 + row) * STRIDE + 60 * BPP
        src = row * SW * BPP
        mm[dst:dst + SW * BPP] = sprite[src:src + SW * BPP]
    time.sleep(2.5)

    mm.flush(); mm.close(); os.close(fd)
    release()

    print("\n==== RESULTS ====")
    for k, v in results.items():
        print(f"{k:28s} {v:8.1f}")
    print("\nfull_frame_memcpy_fps = ceiling for clear+flip.")
    print("sprite96_blits_per_sec = how many 96x96 sprite blits/sec (pre-rendered).")
    print("per_pixel_python_fps = why we pre-render instead of per-pixel loops.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
