import json
from pathlib import Path
import struct
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / '.validation/ui_probe.exe'


def render(width=900, height=514, text_size=115, operations=None):
    if operations is None:
        trace = ROOT / '.validation/general-drawing.json'
        operations = json.loads(trace.read_text()) if trace.is_file() else [
            ['rect', 0, 0, 700, 400, [30, 30, 30]],
            ['text', 10, 10, 600, 30, 'Readable screen-resolution text', [238, 238, 238], 0]]
    payload = bytearray(struct.pack('<4i', width, height, text_size, len(operations)))
    for op in operations:
        if op[0] == 'rect':
            _, x, y, w, h, color = op
            kind, text, align = 1, b'', 0
        else:
            _, x, y, w, h, label, color, align = op
            kind, text = 2, label.encode('utf-16-le')
        rgb = int(color[0]) | int(color[1]) << 8 | int(color[2]) << 16
        payload.extend(struct.pack('<8i', kind, int(x), int(y), int(w), int(h), rgb, align, len(text)//2))
        payload.extend(text)
    return subprocess.run([str(PROBE)], cwd=ROOT, input=payload,
                          capture_output=True, timeout=15, creationflags=0x08000000)


@unittest.skipUnless(PROBE.is_file(), 'optional offscreen GDI probe has not been built')
class DisplayTests(unittest.TestCase):
    def test_native_pixels_and_compact_dpi_layout(self):
        result = render()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout), 900*514*4)
        self.assertEqual(set(result.stdout[3::4]), {255})
        self.assertGreater(len(set(zip(result.stdout[0::4], result.stdout[1::4], result.stdout[2::4]))), 20)

    def test_text_scale_changes_ink_without_changing_footprint(self):
        small, large = render(text_size=100), render(text_size=140)
        self.assertEqual(small.returncode, 0, small.stderr)
        self.assertEqual(large.returncode, 0, large.stderr)
        self.assertEqual(len(small.stdout), len(large.stdout))
        self.assertNotEqual(small.stdout, large.stdout)

    def test_larger_surface_is_rendered_at_its_own_pixel_resolution(self):
        result = render(1400, 800)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout), 1400*800*4)

    def test_invalid_surface_size_is_rejected(self):
        self.assertNotEqual(render(0, 0).returncode, 0)
