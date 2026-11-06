import json
import os
import sys
from pathlib import Path
from typing import Any

from nebula.paths import CONFIG_DIR, SETTINGS, dropin_files


def _user_settings_path() -> Path:
    cfg = Path(os.environ.get("XDG_CONFIG_HOME") or (Path(os.environ.get("HOME") or Path.home()) / ".config")) / "nebula"
    return cfg / "settings.json"


def _read_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def is_path_locked(locks: set[str] | list[str], path: str) -> bool:
    if not locks:
        return False
    parts = path.split(".")
    s_locks = set(locks) if not isinstance(locks, set) else locks
    for i in range(1, len(parts) + 1):
        if ".".join(parts[:i]) in s_locks:
            return True
    return False


def is_key_locked(section_name: str, key: str = "") -> bool:
    path = f"{section_name}.{key}" if key else section_name
    return is_path_locked(get_locks(), path)


def get_locks() -> set[str]:
    locks: set[str] = set()
    for f in dropin_files():
        data = _read_json(f)
        for item in (data.get("locked") or []):
            if isinstance(item, str) and item.strip():
                locks.add(item.strip())
    return locks


def _merge_layer(
    target: dict,
    overlay: dict,
    prefix: str,
    locks: set[str],
    source_name: str,
    sources: dict[str, str],
    enforce_locks: bool,
) -> None:
    for k, v in overlay.items():
        if not prefix and k == "locked":
            continue
        path = f"{prefix}.{k}" if prefix else k
        if enforce_locks and is_path_locked(locks, path):
            continue

        if isinstance(v, dict):
            if k not in target or not isinstance(target[k], dict):
                target[k] = {}
            _merge_layer(target[k], v, path, locks, source_name, sources, enforce_locks)
        else:
            target[k] = v
            sources[path] = source_name


def _build_effective() -> tuple[dict[str, Any], dict[str, str], set[str]]:
    all_locks = get_locks()
    merged: dict[str, Any] = {}
    sources: dict[str, str] = {}

    for f in dropin_files():
        data = _read_json(f)
        _merge_layer(merged, data, "", all_locks, str(f), sources, enforce_locks=False)

    user_file = _user_settings_path()
    if user_file.is_file():
        user_data = _read_json(user_file)
        _merge_layer(merged, user_data, "", all_locks, str(user_file), sources, enforce_locks=True)

    if all_locks:
        merged["locked"] = sorted(all_locks)

    return merged, sources, all_locks


def load() -> dict:
    merged, _, _ = _build_effective()
    return merged


def load_user() -> dict:
    return _read_json(_user_settings_path())


def section(name: str) -> dict:
    sec = load().get(name)
    return dict(sec) if isinstance(sec, dict) else {}


def update(name: str, patch: dict) -> None:
    locks = get_locks()
    user_path = _user_settings_path()
    user_data = load_user()
    sec = dict(user_data.get(name) or {})
    modified = False

    for k in list(sec.keys()):
        if is_path_locked(locks, f"{name}.{k}"):
            sec.pop(k, None)
            modified = True

    for k, v in patch.items():
        path = f"{name}.{k}"
        if is_path_locked(locks, path):
            print(f"nebula: warning: setting '{path}' is locked by administrator; ignoring update", file=sys.stderr)
            continue
        if v is None:
            if k in sec:
                sec.pop(k, None)
                modified = True
        else:
            if sec.get(k) != v:
                sec[k] = v
                modified = True

    if modified:
        if sec:
            user_data[name] = sec
        else:
            user_data.pop(name, None)
        text = json.dumps(user_data, indent=4)
        user_path.parent.mkdir(parents=True, exist_ok=True)
        mode = "r+" if user_path.exists() else "w"
        with open(user_path, mode) as f:
            f.seek(0)
            f.write(text)
            f.truncate()


def get_source(key: str) -> dict:
    merged, sources, locks = _build_effective()
    user_path = str(_user_settings_path())
    locked = is_path_locked(locks, key)

    val = merged
    parts = key.split(".")
    found = True
    for part in parts:
        if isinstance(val, dict) and part in val:
            val = val[part]
        else:
            found = False
            val = None
            break

    src = sources.get(key)
    if src:
        source_type = "user" if src == user_path else "drop-in"
    elif found:
        source_type = "drop-in"
        src = "system drop-in"
    else:
        source_type = "default"
        src = "default"

    return {
        "key": key,
        "value": val,
        "source": src,
        "sourceType": source_type,
        "locked": locked,
    }


def get_all_sources() -> dict:
    merged, sources, locks = _build_effective()
    user_path = str(_user_settings_path())
    dropins = [str(f) for f in dropin_files()]

    flat_settings: list[dict] = []

    def _flatten(obj: dict, prefix: str = "") -> None:
        for k, v in sorted(obj.items()):
            if not prefix and k == "locked":
                continue
            path = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict):
                _flatten(v, path)
            else:
                src = sources.get(path, "default")
                st = "user" if src == user_path else ("drop-in" if src != "default" else "default")
                flat_settings.append({
                    "key": path,
                    "value": v,
                    "source": src,
                    "sourceType": st,
                    "locked": is_path_locked(locks, path),
                })

    _flatten(merged)
    return {
        "dropinFiles": dropins,
        "locked": sorted(locks),
        "settings": flat_settings,
    }
