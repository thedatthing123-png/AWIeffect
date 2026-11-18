"""Run a declared subset of the once-built XCTest products without recompiling."""
import json
import os
from pathlib import Path
import subprocess
from test_shards import inventory, selectors

scope=os.environ.get('TEST_SCOPE','all')
shard=os.environ['TEST_SHARD']
flags=selectors(scope,shard)
Path('test-inventory.json').write_text(json.dumps({'scope':scope,'shard':shard,'selectors':flags},indent=2))
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))['devices']
phones=[device['udid'] for runtime,items in devices.items() if 'iOS' in runtime for device in items if device['name'].startswith('iPhone')]
if not phones: raise RuntimeError('No available iPhone simulator')
products=Path('build/TestBuild/Build/Products')
runs=list(products.glob('*.xctestrun'))
if len(runs)!=1: raise RuntimeError(f'Expected one relocatable xctestrun, got {runs}')
command=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','id='+phones[-1],
         '-resultBundlePath','TestResults.xcresult','-parallel-testing-enabled','NO',
         '-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240',
         '-maximum-test-execution-time-allowance','600']+flags
print(f'Running {shard}: {len(flags)} tests on {phones[-1]}',flush=True)
with open('test.log','w',buffering=1) as log:
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    for line in process.stdout:
        log.write(line)
        if any(word in line for word in ['error:','Test Case','Executed','SKIP','FAIL','Fatal','crashed','Restarting','exceeded']):
            # Huge pixel-array assertions belong in the raw artifact, not the console.
            print(line[:3000],end='' if line.endswith('\n') else '\n',flush=True)
    status=process.wait()
raise SystemExit(status)
