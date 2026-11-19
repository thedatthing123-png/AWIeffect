"""Readable console summary; leave the complete raw report in test-results."""
import json
import re
import sys
from pathlib import Path

def compact(value):
    if isinstance(value, dict):
        return {key: compact(item) for key, item in value.items()}
    if isinstance(value, list):
        return [compact(item) for item in value]
    if isinstance(value, str):
        return re.sub(r'\[[\d, .-]{100,}\]', '[pixel array]', value)
    return value

if __name__ == '__main__':
    print(json.dumps(compact(json.loads(Path(sys.argv[1]).read_text())), indent=2))
