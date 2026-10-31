import json
import sys

# Prints every failed test with its failure messages from `xcresulttool get test-results tests` JSON.
data = json.load(sys.stdin)


def walk(node, path):
    name = node.get("name", "")
    kids = node.get("children", []) or []
    if node.get("nodeType") == "Test Case" and node.get("result") == "Failed":
        msgs = [k.get("name", "") for k in kids if k.get("nodeType") == "Failure Message"]
        for m in msgs or ["(no message)"]:
            print("SKIP-FAIL " + name + " :: " + m[:400])
    for k in kids:
        walk(k, path + [name])


for n in data.get("testNodes", []):
    walk(n, [])
