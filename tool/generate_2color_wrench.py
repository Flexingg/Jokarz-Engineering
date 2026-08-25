import zlib
import struct
import math
import os

def create_png(width, height, pixel_data):
    def make_chunk(chunk_type, data):
        return struct.pack('>I', len(data)) + chunk_type + data + struct.pack('>I', zlib.crc32(chunk_type + data) & 0xffffffff)

    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0) # filter type none
        for x in range(width):
            r, g, b, a = pixel_data[y * width + x]
            raw_data.extend([r, g, b, a])

    compressed = zlib.compress(bytes(raw_data), 9)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)

    png_bytes = b'\x89PNG\r\n\x1a\n'
    png_bytes += make_chunk(b'IHDR', ihdr)
    png_bytes += make_chunk(b'IDAT', compressed)
    png_bytes += make_chunk(b'IEND', b'')
    return png_bytes

def draw_2color_wrench(size):
    # 2 Colors: Background = #0F172A (RGB: 15, 23, 42), Foreground = Pure White #FFFFFF (RGB: 255, 255, 255)
    bg = (15, 23, 42, 255)
    fg = (255, 255, 255, 255)
    pixels = [bg] * (size * size)

    cx = size / 2.0
    cy = size / 2.0
    scale = size / 100.0

    # Wrench angle: -45 degrees (diagonal from bottom-left to top-right)
    cos_a = math.cos(math.radians(-45))
    sin_a = math.sin(math.radians(-45))

    for y in range(size):
        for x in range(size):
            # Transform to centered coordinates rotated
            dx = (x - cx) / scale
            dy = (y - cy) / scale
            
            # Rotated coordinates (along wrench shaft)
            rx = dx * cos_a - dy * sin_a
            ry = dx * sin_a + dy * cos_a

            is_wrench = False

            # Shaft: length from rx = -28 to +22, thickness ry from -5.0 to +5.0
            if -28 <= rx <= 22 and -4.8 <= ry <= 4.8:
                is_wrench = True

            # Open-end Wrench Head (Top Right around rx = 24, ry = 0)
            head_dx = rx - 24
            head_dy = ry
            head_dist = math.sqrt(head_dx*head_dx + head_dy*head_dy)

            # Outer circle of head
            if head_dist <= 14.5:
                # Cutout for open jaw (U-shape notch pointing outward at +rx)
                # Jaw angle notch
                jaw_dx = rx - 27
                jaw_dy = ry
                if not (rx > 18 and abs(ry) <= 6.0 and jaw_dx < 6.0):
                    is_wrench = True

            # Box-end / Ring Wrench Head (Bottom Left around rx = -28, ry = 0)
            ring_dx = rx - (-28)
            ring_dy = ry
            ring_dist = math.sqrt(ring_dx*ring_dx + ring_dy*ring_dy)
            if ring_dist <= 13.0 and ring_dist >= 6.5:
                is_wrench = True

            if is_wrench:
                pixels[y * size + x] = fg

    return pixels

def main():
    sizes = {
        'assets/icons/app_icon.png': 512,
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    }

    base_dir = r'C:\RandallEngineering\Jokarz-Engineering'

    for rel_path, sz in sizes.items():
        out_path = os.path.join(base_dir, rel_path)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        pixels = draw_2color_wrench(sz)
        png_data = create_png(sz, sz, pixels)
        with open(out_path, 'wb') as f:
            f.write(png_data)
        print(f"Generated {out_path} ({sz}x{sz})")

if __name__ == '__main__':
    main()
