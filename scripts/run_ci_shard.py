"""Run a declared subset of the once-built XCTest products without recompiling."""
import json
import os
from pathlib import Path
import signal
import subprocess
import threading

scope=os.environ.get('TEST_SCOPE','all')
shard=os.environ['TEST_SHARD']
flags=['-only-testing:AWIeffectUITests/RigAuthoringUITests/testRecordArtworkRigMotion']
Path('test-inventory.json').write_text(json.dumps({'scope':scope,'shard':shard,'selectors':flags},indent=2))
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))['devices']
phones=[device['udid'] for runtime,items in devices.items() if 'iOS' in runtime for device in items if device['name'].startswith('iPhone')]
if not phones: raise RuntimeError('No available iPhone simulator')
state=subprocess.run(['xcrun','simctl','boot',phones[-1]],capture_output=True,text=True)
# A reused runner may already have it booted. bootstatus waits for SpringBoard
# before XCUITest asks Accessibility to initialize, instead of racing first boot.
subprocess.run(['xcrun','simctl','bootstatus',phones[-1],'-b'],check=True,timeout=240)
products=Path('build/TestBuild/Build/Products')
runs=list(products.glob('*.xctestrun'))
if len(runs)!=1: raise RuntimeError(f'Expected one relocatable xctestrun, got {runs}')
command=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','id='+phones[-1],
         '-resultBundlePath','TestResults.xcresult','-parallel-testing-enabled','NO',
         '-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240',
         '-maximum-test-execution-time-allowance','600']+flags
print(f'Running {shard}: {len(flags)} tests on {phones[-1]}',flush=True)
ready=Path('/tmp/awi-record-rig')
ready.unlink(missing_ok=True)
output=Path('/tmp/awi-ui')
output.mkdir(exist_ok=True)
capture_stopped=threading.Event()

def record():
    while not ready.exists():
        if capture_stopped.wait(0.1):
            return
    with (output/'recorder.log').open('w') as diagnostics:
        capture=subprocess.Popen(
            ['xcrun','simctl','io',phones[-1],'recordVideo','--codec=h264','--force',
             str(output/'rig-motion.mp4')],
            stdout=diagnostics, stderr=subprocess.STDOUT)
        capture_stopped.wait()
        if capture.poll() is None:
            capture.send_signal(signal.SIGINT)
        capture.wait(timeout=20)

recorder=threading.Thread(target=record)
recorder.start()
with open('test.log','w',buffering=1) as log:
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    for line in process.stdout:
        log.write(line)
        if any(word in line for word in ['error:','Test Case','Executed','SKIP','FAIL','Fatal','crashed','Restarting','exceeded']):
            # Huge pixel-array assertions belong in the raw artifact, not the console.
            print(line[:3000],end='' if line.endswith('\n') else '\n',flush=True)
    status=process.wait()
capture_stopped.set()
recorder.join()
assert (output/'rig-motion.mp4').is_file(), 'No simulator playback was captured'
raise SystemExit(status)
