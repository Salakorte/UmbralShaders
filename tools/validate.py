"""Resolve Iris includes and compile/link every profile on a hidden Windows GL context.

No third party Python packages. This is a driver GLSL check, not Iris integration QA.
Usage: python tools/validate.py [--static-only]
"""
from pathlib import Path
import ctypes as c
from ctypes import wintypes as w
import itertools
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / 'shaders'


def expand(path, stack=()):
    path = path.resolve()
    if not path.is_relative_to(SHADERS) or path in stack:
        raise ValueError(f'Unsafe or cyclic include: {path}')
    source = path.read_text(encoding='utf-8')
    return re.sub(r'^\s*#include\s+"([^"]+)"\s*$',
                  lambda m: expand(SHADERS / m[1].lstrip('/'), (*stack, path)),
                  source, flags=re.M)


def configured(source, settings):
    for key, value in settings.items():
        if key == 'SHADOWS_ENABLED':
            if not value:
                source = re.sub(r'^#define SHADOWS_ENABLED\b.*$',
                                '// SHADOWS_ENABLED disabled', source, flags=re.M)
        elif key in ('shadowDistance', 'shadowMapResolution'):
            source = re.sub(r'(const (?:float|int) ' + key + r' = )[^;]+;',
                            lambda m: m[1] + str(value) + ';', source)
        else:
            source = re.sub(r'(^#define ' + key + r' )\S+',
                            lambda m: m[1] + str(value), source, flags=re.M)
    return source


class Driver:
    """Create an invisible legacy WGL context; modern NVIDIA/AMD expose GLSL here."""
    def __init__(self):
        self.user = c.WinDLL('user32', use_last_error=True)
        self.gdi = c.WinDLL('gdi32', use_last_error=True)
        self.gl = c.WinDLL('opengl32', use_last_error=True)
        self.user.CreateWindowExW.argtypes = [w.DWORD, w.LPCWSTR, w.LPCWSTR, w.DWORD,
                                             c.c_int, c.c_int, c.c_int, c.c_int,
                                             w.HWND, w.HMENU, w.HINSTANCE, c.c_void_p]
        self.user.CreateWindowExW.restype = w.HWND
        self.user.GetDC.argtypes = [w.HWND]
        self.user.GetDC.restype = w.HDC
        self.window = self.user.CreateWindowExW(0, 'STATIC', 'GLSL validation', 0,
                                               0, 0, 1, 1, None, None, None, None)
        if not self.window:
            raise OSError('Cannot create hidden validation window')
        self.dc = self.user.GetDC(self.window)

        class PFD(c.Structure):
            _fields_ = [('nSize', w.WORD), ('nVersion', w.WORD), ('dwFlags', w.DWORD),
                        *[(n, c.c_ubyte) for n in ('iPixelType', 'cColorBits', 'cRedBits',
                        'cRedShift', 'cGreenBits', 'cGreenShift', 'cBlueBits', 'cBlueShift',
                        'cAlphaBits', 'cAlphaShift', 'cAccumBits', 'cAccumRedBits',
                        'cAccumGreenBits', 'cAccumBlueBits', 'cAccumAlphaBits', 'cDepthBits',
                        'cStencilBits', 'cAuxBuffers', 'iLayerType', 'bReserved')],
                        ('dwLayerMask', w.DWORD), ('dwVisibleMask', w.DWORD),
                        ('dwDamageMask', w.DWORD)]
        pfd = PFD()
        pfd.nSize, pfd.nVersion = c.sizeof(PFD), 1
        pfd.dwFlags, pfd.cColorBits, pfd.cDepthBits = 0x24, 24, 24
        self.gdi.ChoosePixelFormat.argtypes = [w.HDC, c.POINTER(PFD)]
        self.gdi.SetPixelFormat.argtypes = [w.HDC, c.c_int, c.POINTER(PFD)]
        fmt = self.gdi.ChoosePixelFormat(self.dc, c.byref(pfd))
        if not fmt or not self.gdi.SetPixelFormat(self.dc, fmt, c.byref(pfd)):
            raise OSError('Cannot configure WGL pixel format')
        self.gl.wglCreateContext.argtypes = [w.HDC]
        self.gl.wglCreateContext.restype = c.c_void_p
        self.gl.wglMakeCurrent.argtypes = [w.HDC, c.c_void_p]
        self.context = self.gl.wglCreateContext(self.dc)
        if not self.context or not self.gl.wglMakeCurrent(self.dc, self.context):
            raise OSError('Cannot activate WGL context')
        self.gl.wglGetProcAddress.argtypes = [c.c_char_p]
        self.gl.wglGetProcAddress.restype = c.c_void_p
        self.gl.glGetString.argtypes = [c.c_uint]
        self.gl.glGetString.restype = c.c_char_p
        self.info = {name: (self.gl.glGetString(enum) or b'unavailable').decode()
                     for name, enum in [('vendor', 0x1F00), ('renderer', 0x1F01),
                                        ('version', 0x1F02), ('glsl', 0x8B8C)]}
        self.createShader = self.proc('glCreateShader', c.c_uint, c.c_uint)
        self.shaderSource = self.proc('glShaderSource', None, c.c_uint, c.c_int,
                                      c.POINTER(c.c_char_p), c.POINTER(c.c_int))
        self.compileShader = self.proc('glCompileShader', None, c.c_uint)
        self.getShaderiv = self.proc('glGetShaderiv', None, c.c_uint, c.c_uint, c.POINTER(c.c_int))
        self.getShaderInfoLog = self.proc('glGetShaderInfoLog', None, c.c_uint, c.c_int,
                                          c.POINTER(c.c_int), c.c_void_p)
        self.createProgram = self.proc('glCreateProgram', c.c_uint)
        self.attachShader = self.proc('glAttachShader', None, c.c_uint, c.c_uint)
        self.linkProgram = self.proc('glLinkProgram', None, c.c_uint)
        self.getProgramiv = self.proc('glGetProgramiv', None, c.c_uint, c.c_uint, c.POINTER(c.c_int))
        self.getProgramInfoLog = self.proc('glGetProgramInfoLog', None, c.c_uint, c.c_int,
                                           c.POINTER(c.c_int), c.c_void_p)
        self.deleteShader = self.proc('glDeleteShader', None, c.c_uint)
        self.deleteProgram = self.proc('glDeleteProgram', None, c.c_uint)

    def proc(self, name, result, *args):
        address = self.gl.wglGetProcAddress(name.encode())
        if address in (None, 1, 2, 3, -1):
            raise OSError(f'{name} unavailable; context: {self.info}')
        return c.WINFUNCTYPE(result, *args)(address)

    def check(self, obj, shader):
        status = c.c_int()
        get = self.getShaderiv if shader else self.getProgramiv
        get(obj, 0x8B81 if shader else 0x8B82, c.byref(status))
        if not status.value:
            log = c.create_string_buffer(16384)
            (self.getShaderInfoLog if shader else self.getProgramInfoLog)(obj, len(log), None, log)
            raise RuntimeError(log.value.decode(errors='replace'))

    def compile_pair(self, vertex, fragment):
        objects = []
        program = self.createProgram()
        try:
            for enum, source in [(0x8B31, vertex), (0x8B30, fragment)]:
                shader = self.createShader(enum)
                objects.append(shader)
                data = c.c_char_p(source.encode())
                self.shaderSource(shader, 1, c.byref(data), None)
                self.compileShader(shader)
                self.check(shader, True)
                self.attachShader(program, shader)
            self.linkProgram(program)
            self.check(program, False)
        finally:
            self.deleteProgram(program)
            for shader in objects:
                self.deleteShader(shader)

    def close(self):
        self.gl.wglMakeCurrent(self.dc, None)
        self.gl.wglDeleteContext.argtypes = [c.c_void_p]
        self.gl.wglDeleteContext(self.context)
        self.user.ReleaseDC.argtypes = [w.HWND, w.HDC]
        self.user.ReleaseDC(self.window, self.dc)
        self.user.DestroyWindow.argtypes = [w.HWND]
        self.user.DestroyWindow(self.window)


def main():
    pairs = []
    for vertex in sorted(SHADERS.rglob('*.vsh')):
        if 'lib' in vertex.relative_to(SHADERS).parts:
            continue
        fragment = vertex.with_suffix('.fsh')
        assert fragment.exists(), fragment
        pair = (expand(vertex), expand(fragment))
        assert all(s.startswith(('#version 330 compatibility\n', '#version 430 compatibility\n')) for s in pair)
        assert all(s.count('#version') == 1 for s in pair)
        pairs.append((str(vertex.relative_to(SHADERS).with_suffix('')), pair))
    assert len([p for p in SHADERS.rglob('*.fsh')
                if 'lib' not in p.relative_to(SHADERS).parts]) == len(pairs)
    report = {'program_pairs': len(pairs), 'include_checks': 'passed',
              'iris_runtime': 'NOT TESTED', 'visual_tests': 'NOT TESTED',
              'performance': 'NOT TESTED'}
    # Cover both ends of the distance slider and every quality preset distance.
    variants = list(itertools.product((False, True), (0, 1, 2),
                                     ('1.0', '32.0', '96.0', '256.0', '2048.0'), (1024, 2048, 4096),
                                     ('0.0', '0.15', '0.25', '0.35', '0.45', '0.50'), (0, 1)))
    driver = None
    try:
        if '--static-only' not in sys.argv:
            driver = Driver()
            report['driver'] = driver.info
            count = 0
            # Geometry without receivers doesn't depend on quality settings;
            # compile once. Exercise all options on every shadow receiver pair.
            for name, pair in pairs:
                if '#define VS_RECEIVES_SHADOWS\n' in pair[1]:
                    cases = variants
                elif name == 'shadow':
                    cases = [(True, 1, distance, resolution, '0.35', 0)
                             for distance in ('1.0', '96.0', '512.0', '2048.0')
                             for resolution in (1024, 4096)]
                else:
                    cases = [variants[-1]]
                for enabled, softness, distance, resolution, intensity, style in cases:
                    settings = dict(SHADOWS_ENABLED=enabled, SHADOW_SOFTNESS=softness,
                                    shadowDistance=distance, shadowMapResolution=resolution,
                                    SHADOW_INTENSITY=intensity, SHADOW_STYLE=style)
                    try:
                        driver.compile_pair(*(configured(s, settings) for s in pair))
                    except Exception as exc:
                        raise RuntimeError(f'{name} {settings}: {exc}') from exc
                    count += 1
                if name.endswith(('deferred', 'deferred1')):
                    for quality, gi_intensity in itertools.product((0, 1, 2), ('0.25', '1.50', '3.00')):
                        fragment = pair[1].replace('\n', '\n#define RAY_TRACED_GI\n', 1)
                        driver.compile_pair(pair[0], configured(fragment, {
                            'GI_QUALITY': quality, 'GI_INTENSITY': gi_intensity,
                        }))
                        count += 1
                feature_header = '#define MC_RENDER_STAGE_TERRAIN_SOLID 1\n'
                feature_cases = []
                if name in ('shadow', 'shadow_water', 'gbuffers_terrain', 'deferred', 'deferred1'):
                    feature_cases.extend([('RT_BLOCK_LIGHTS',), ('RT_GLASS_TRANSMISSION',),
                                          ('RT_BLOCK_LIGHTS', 'RT_GLASS_TRANSMISSION')])
                if name in ('gbuffers_terrain', 'deferred', 'deferred1'):
                    feature_cases.extend([('RT_BLOCK_LIGHTS', 'RAY_TRACED_GI'),
                                          ('RT_GLASS_TRANSMISSION', 'RAY_TRACED_GI'),
                                          ('RT_BLOCK_LIGHTS', 'RT_GLASS_TRANSMISSION', 'RAY_TRACED_GI')])
                if name in ('gbuffers_terrain', 'shadow'):
                    feature_cases.append(('RAY_TRACED_GI',))
                if name.endswith('gbuffers_water'):
                    feature_cases.extend([('RT_WATER_REFLECTIONS',), ('RT_GLASS_REFLECTIONS',),
                                          ('RT_WATER_REFLECTIONS', 'RT_GLASS_REFLECTIONS')])
                for flags in feature_cases:
                    header = feature_header + ''.join(f'#define {flag}\n' for flag in flags)
                    configured_pair = tuple(s.replace('\n', '\n' + header, 1) for s in pair)
                    qualities = (0, 1, 2) if name == 'gbuffers_terrain' else (1,)
                    for quality in qualities:
                        driver.compile_pair(*(configured(s, {'GI_QUALITY': quality}) for s in configured_pair))
                        count += 1
                # Simulate the DH compile-time inputs that Iris supplies.
                # The OpenGL driver check does not execute the actual patcher.
                if name.startswith('dh_') or '/dh_' in name.replace('\\', '/') or name.endswith('gbuffers_terrain'):
                    vertex_preamble = '#define DISTANT_HORIZONS\n'
                    if name == 'dh_shadow':
                        vertex_preamble += '#define DH_BLOCK_WATER 1\nin int dhMaterialId;\n'
                    fragment_preamble = '#define DISTANT_HORIZONS\n#define DH_CAST_SHADOWS\n'
                    dh_pair = tuple(source.replace('\n', '\n' + preamble, 1)
                                    for source, preamble in zip(pair, (vertex_preamble, fragment_preamble)))
                    for style in (0, 1):
                        for distance in ('96.0', '2048.0'):
                            driver.compile_pair(*(configured(source, {'SHADOW_STYLE': style, 'shadowDistance': distance})
                                                  for source in dh_pair))
                            count += 1
            report['compiled_and_linked_variants'] = count
            computes = sorted(SHADERS.glob('shadowcomp*.csh'))
            for path in computes:
                compute = expand(path).replace('\n', '\n#define RT_BLOCK_LIGHTS\n#define RT_GLASS_TRANSMISSION\n', 1)
                shader = driver.createShader(0x91B9)
                program = driver.createProgram()
                try:
                    data = c.c_char_p(compute.encode())
                    driver.shaderSource(shader, 1, c.byref(data), None)
                    driver.compileShader(shader)
                    driver.check(shader, True)
                    driver.attachShader(program, shader)
                    driver.linkProgram(program)
                    driver.check(program, False)
                finally:
                    driver.deleteProgram(program)
                    driver.deleteShader(shader)
            report['compute_programs'] = len(computes)
            report['glsl_driver_validation'] = 'passed'
        else:
            report['glsl_driver_validation'] = 'NOT TESTED'
    except Exception as exc:
        report['glsl_driver_validation'] = 'failed or unavailable'
        report['error'] = str(exc)
        raise
    finally:
        if driver:
            driver.close()
        (ROOT / 'build').mkdir(exist_ok=True)
        (ROOT / 'build' / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
