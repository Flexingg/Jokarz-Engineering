import os
import zlib
import struct

def parse_png(data):
    # Basic PNG parser
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    idx = 8
    width = height = None
    idat_chunks = []
    
    while idx < len(data):
        length, chunk_type = struct.unpack('>II', data[idx:idx+8])
        chunk_data = data[idx+8:idx+8+length]
        idx += 12 + length
        
        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type, comp, filt, interlace = struct.unpack('>IIBBBBB', chunk_data)
        elif chunk_type == b'IDAT':
            idat_chunks.append(chunk_data)
        elif chunk_type == b'IEND':
            break
            
    decompressed = zlib.decompress(b''.join(idat_chunks))
    
    # Reconstruct RGBA matrix
    pixels = []
    stride = width * 4 + 1
    for y in range(height):
        row = decompressed[y * stride + 1 : (y + 1) * stride]
        for x in range(width):
            r = row[x*4]
            g = row[x*4 + 1]
            b = row[x*4 + 2]
            a = row[x*4 + 3]
            pixels.append((r, g, b, a))
            
    return width, height, pixels

def resize_pixels(src_w, src_h, src_pixels, dst_w, dst_h):
    dst_pixels = []
    for dy in range(dst_h):
        for dx in range(dst_w):
            # Box sampling / nearest-bilinear
            sx_start = int(dx * src_w / dst_w)
            sx_end = max(sx_start + 1, int((dx + 1) * src_w / dst_w))
            sy_start = int(dy * src_h / dst_h)
            sy_end = max(sy_start + 1, int((dy + 1) * src_h / dst_h))
            
            r_sum = g_sum = b_sum = a_sum = count = 0
            for sy in range(sy_start, min(sy_end, src_h)):
                for sx in range(sx_start, min(sx_end, src_w)):
                    r, g, b, a = src_pixels[sy * src_w + sx]
                    r_sum += r * a
                    g_sum += g * a
                    b_sum += b * a
                    a_sum += a
                    count += 1
                    
            if a_sum > 0 and count > 0:
                avg_a = a_sum // count
                avg_r = (r_sum // a_sum)
                avg_g = (g_sum // a_sum)
                avg_b = (b_sum // a_sum)
                dst_pixels.append((avg_r, avg_g, avg_b, avg_a))
            else:
                dst_pixels.append((0, 0, 0, 0))
    return dst_pixels

def create_png(width, height, pixel_data):
    def make_chunk(chunk_type, data):
        return struct.pack('>I', len(data)) + chunk_type + data + struct.pack('>I', zlib.crc32(chunk_type + data) & 0xffffffff)

    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)
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

def main():
    src_icon_path = r'C:\Users\Jonat\.gemini\antigravity\brain\a9450711-c829-42ae-be16-d1696bb2b979\.user_uploaded\media_1787694354182.png'
    with open(src_icon_path, 'rb') as f:
        src_data = f.read()

    w, h, pixels = parse_png(src_data)
    print(f"Loaded source image: {w}x{h}")

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
        if sz == w and sz == h:
            scaled = pixels
        else:
            scaled = resize_pixels(w, h, pixels, sz, sz)
        png_data = create_png(sz, sz, scaled)
        with open(out_path, 'wb') as f:
            f.write(png_data)
        print(f"Generated {out_path} ({sz}x{sz})")

if __name__ == '__main__':
    main()
