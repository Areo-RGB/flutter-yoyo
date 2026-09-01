#!/usr/bin/env python3
import os
import re
import sys
import subprocess

PUBSPEC_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "pubspec.yaml")

def get_current_version():
    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        content = f.read()
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)", content, re.MULTILINE)
    if match:
        return match.group(1)
    raise ValueError("Could not find version string in pubspec.yaml")

def update_version(new_version):
    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        content = f.read()
    updated = re.sub(r"^version:\s*[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?", f"version: {new_version}", content, flags=re.MULTILINE)
    with open(PUBSPEC_PATH, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Updated pubspec.yaml version to: {new_version}")

def run_cmd(cmd):
    print(f"Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error: {res.stderr.strip()}")
        sys.exit(res.returncode)
    return res.stdout.strip()

def main():
    current_ver = get_current_version()
    print(f"Current version: {current_ver}")

    if len(sys.argv) > 1:
        raw_new_ver = sys.argv[1].lstrip("v")
    else:
        # Auto bump patch version if no argument provided
        parts = current_ver.split("+")
        semver = parts[0].split(".")
        major, minor, patch = int(semver[0]), int(semver[1]), int(semver[2])
        build = int(parts[1]) if len(parts) > 1 else 1
        raw_new_ver = f"{major}.{minor}.{patch + 1}+{build + 1}"
        print(f"No version supplied. Auto-bumping to: {raw_new_ver}")

    # Ensure build number exists (e.g. 1.0.1+2)
    if "+" not in raw_new_ver:
        raw_new_ver += "+1"

    semver_tag = raw_new_ver.split("+")[0]
    git_tag = f"v{semver_tag}"

    print(f"New Version: {raw_new_ver}")
    print(f"Git Tag: {git_tag}")

    # 1. Update pubspec.yaml
    update_version(raw_new_ver)

    # 2. Stage changes & commit
    run_cmd(["git", "add", "pubspec.yaml"])
    if os.path.exists("pubspec.lock"):
        run_cmd(["git", "add", "pubspec.lock"])
    
    commit_msg = f"chore(release): bump version to {raw_new_ver}"
    run_cmd(["git", "commit", "-m", commit_msg])
    print(f"Created commit: '{commit_msg}'")

    # 3. Create git tag
    run_cmd(["git", "tag", "-a", git_tag, "-m", f"Release {git_tag}"])
    print(f"Created git tag: {git_tag}")

    # 4. Prompt / instructions for push
    print("\n" + "="*50)
    print(f"SUCCESS! Version bumped to {raw_new_ver} and tagged as {git_tag}.")
    print("To trigger the GitHub Actions build & release pipeline, run:")
    print(f"  git push yoyo-ir1 main --tags")
    print("="*50 + "\n")

if __name__ == "__main__":
    main()
