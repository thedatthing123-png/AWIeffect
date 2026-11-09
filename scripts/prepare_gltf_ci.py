"""Use the exact upstream binary through gh when SwiftPM's release download returns 504.
The SHA-256 is the one published in GLTFKit2 0.5.15's Package.swift.
Only the ephemeral CI project specification is changed; product dependency/version stay identical.
"""
import hashlib
import os
from pathlib import Path
import subprocess
import zipfile

root = Path(os.environ['RUNNER_TEMP']) / 'awi-gltf-0.5.15'
root.mkdir(parents=True, exist_ok=True)
subprocess.run(['gh','release','download','0.5.15','--repo','warrenm/GLTFKit2','--pattern',
                'GLTFKit2.xcframework.zip','--dir',str(root),'--clobber'],check=True)
archive = root / 'GLTFKit2.xcframework.zip'
expected = '9d0c338282acce4986494aa02a5f1495278f56c60d43f31453fefea6875b4928'
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise RuntimeError('GLTFKit2 upstream checksum mismatch')
with zipfile.ZipFile(archive) as bundle:
    for name in bundle.namelist():
        if not (root / name).resolve().is_relative_to(root.resolve()):
            raise RuntimeError('Invalid framework archive path')
    bundle.extractall(root)
if not (root / 'GLTFKit2.xcframework').is_dir():
    raise RuntimeError('Expected upstream framework is missing')
(root / 'Package.swift').write_text('''// swift-tools-version: 5.5
import PackageDescription
let package = Package(name: "GLTFKit2",
    platforms: [.macOS("11.0"), .macCatalyst("14.0"), .iOS("12.1"), .tvOS("12.1")],
    products: [.library(name: "GLTFKit2", targets: ["GLTFKit2"])],
    targets: [.binaryTarget(name: "GLTFKit2", path: "GLTFKit2.xcframework")])
''', encoding='utf-8')
spec = Path('project.yml')
content = spec.read_text(encoding='utf-8-sig')
old = '    url: https://github.com/warrenm/GLTFKit2.git\n    exactVersion: 0.5.15'
if old not in content:
    raise RuntimeError('Dependency specification changed; verify the pin before updating CI')
content = content.replace(old, '    path: "' + root.as_posix() + '"', 1)
spec.write_text(content, encoding='utf-8')
print('Verified and prepared unchanged GLTFKit2 0.5.15 binary for CI')
