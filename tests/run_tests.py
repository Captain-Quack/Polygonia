"""Run Godot SceneTree tests, treating engine script errors as failures too."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
commands = [("editor import", ["--editor", "--quit"])]
commands += [(p.name, ["--script", str(p.relative_to(root))])
             for p in sorted((root / "tests").glob("test_*.gd"))]
commands += [("world startup", ["--quit-after", "20"])]
failures = []
for name, args in commands:
    try:
        result = subprocess.run([godot, "--headless", "--path", str(root), *args],
                                capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        ok = result.returncode == 0 and "ERROR:" not in output
    except subprocess.TimeoutExpired:
        ok, output = False, "Timed out after 60 seconds"
    print(f"{'PASS' if ok else 'FAIL'} {name}", flush=True)
    if not ok:
        failures.append(name)
        print(output, flush=True)
print(f"{len(commands) - len(failures)}/{len(commands)} checks passed")
sys.exit(bool(failures))
