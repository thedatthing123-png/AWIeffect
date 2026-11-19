"""Compile every Metal file for simulator/device and report all failures together.
Requires Apple's Xcode Metal toolchain. Outputs diagnostics even when one file fails.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
output = root / 'build_out' / 'metal-preflight'
output.mkdir(parents=True, exist_ok=True)
sources = sorted((root / 'App').rglob('*.metal'))
failures = []
for sdk, target in [('iphonesimulator', 'air64-apple-ios18.0-simulator'), ('iphoneos', 'air64-apple-ios18.0')]:
    sdkroot = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
    destination = output / sdk
    destination.mkdir(exist_ok=True)
    def compile_source(source):
        relative = source.relative_to(root)
        artifact = destination / ('_'.join(relative.parts) + '.air')
        command = ['xcrun', '--sdk', sdk, 'metal', '-target', target, '-isysroot', sdkroot,
                   '-c', str(source), '-o', str(artifact)]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return source, artifact, result.returncode, result.stdout
    # Keep memory predictable on hosted runners and gather every compiler diagnostic.
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(compile_source, sources))
    log = []
    for source, artifact, status, diagnostics in results:
        heading = f'{sdk}: {source.relative_to(root)}: {"FAIL" if status else "PASS"}'
        print(heading, flush=True)
        log.append(heading + '\n' + diagnostics)
        if diagnostics:
            print(diagnostics, flush=True)
        if status:
            failures.append(heading)
    if all(status == 0 for _, _, status, _ in results):
        link = subprocess.run(['xcrun', '--sdk', sdk, 'metallib', *[str(item[1]) for item in results],
                               '-o', str(destination / 'all-shaders.metallib')], text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log.append(link.stdout)
        if link.stdout:
            print(link.stdout, flush=True)
        if link.returncode:
            failures.append(f'{sdk}: metallib link failed')
    (destination / 'compile.log').write_text('\n'.join(log), encoding='utf-8')
print(f'Metal preflight: {len(sources)} files x 2 SDKs, {len(failures)} failures', flush=True)
for failure in failures:
    print('::error::' + failure, flush=True)
sys.exit(1 if failures else 0)
