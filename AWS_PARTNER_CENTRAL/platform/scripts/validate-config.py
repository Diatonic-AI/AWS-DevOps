#!/usr/bin/env python3
"""
Configuration validation script for Partner Central Wrapper Platform.
Validates all YAML configuration files against expected schemas.
"""

import sys
import os
from pathlib import Path

try:
    import yaml
except ImportError:
    print("[ERROR] PyYAML not installed. Run: pip install pyyaml")
    sys.exit(1)

# Configuration validation rules
REQUIRED_FILES = [
    ("platform.yaml", ["platform", "tenancy", "approval_gates", "data", "observability"]),
    ("connectors.yaml", ["connectors"]),
    ("products.yaml", ["products"]),
]

OPTIONAL_FILES = [
    ("tenants.yaml", ["tenants"]),
    ("policies.yaml", ["policies"]),
    ("feature-flags.yaml", ["feature_flags"]),
]


def get_config_dir() -> Path:
    """Get the configuration directory path."""
    script_dir = Path(__file__).parent
    config_dir = script_dir.parent / "config"
    return config_dir


def load_yaml(path: Path) -> dict:
    """Load a YAML file and return its contents."""
    with open(path, "r") as f:
        return yaml.safe_load(f)


def has_keys(obj: dict, keys: list) -> tuple[bool, str]:
    """Check if a nested key path exists in a dictionary."""
    current = obj
    for i, key in enumerate(keys):
        if not isinstance(current, dict):
            return False, f"Expected dict at '{'.'.join(keys[:i])}', got {type(current).__name__}"
        if key not in current:
            return False, f"Missing key '{key}' in path '{'.'.join(keys[:i+1])}'"
        current = current[key]
    return True, ""


def validate_platform_config(config: dict) -> list[str]:
    """Validate platform.yaml specific rules."""
    errors = []

    # Check platform name
    if "platform" in config:
        platform = config["platform"]
        if "name" not in platform:
            errors.append("platform.name is required")
        if "version" not in platform:
            errors.append("platform.version is required")

    # Check tenancy model
    if "tenancy" in config:
        tenancy = config["tenancy"]
        valid_models = ["pooled_compute_isolated_data", "siloed", "hybrid"]
        if tenancy.get("model") not in valid_models:
            errors.append(f"tenancy.model must be one of: {valid_models}")

    # Check approval gates
    if "approval_gates" in config:
        gates = config["approval_gates"]
        valid_modes = ["manual", "automatic"]
        if gates.get("action_approval_mode") not in valid_modes:
            errors.append(f"approval_gates.action_approval_mode must be one of: {valid_modes}")

    return errors


def validate_connectors_config(config: dict) -> list[str]:
    """Validate connectors.yaml specific rules."""
    errors = []

    if "connectors" in config:
        connectors = config["connectors"]

        # Check Partner Central connector
        if "partner_central" in connectors:
            pc = connectors["partner_central"]
            valid_modes = ["batch", "streaming", "hybrid"]
            if pc.get("mode") not in valid_modes:
                errors.append(f"connectors.partner_central.mode must be one of: {valid_modes}")

    return errors


def validate_products_config(config: dict) -> list[str]:
    """Validate products.yaml specific rules."""
    errors = []

    if "products" in config:
        products = config["products"]

        if "plans" not in products:
            errors.append("products.plans is required")
        else:
            plans = products["plans"]
            required_plans = ["foundation", "scale", "enterprise"]
            for plan in required_plans:
                if plan not in plans:
                    errors.append(f"products.plans.{plan} is required")

    return errors


def validate_file(
    config_dir: Path,
    filename: str,
    required_paths: list,
    is_required: bool = True
) -> tuple[bool, list[str]]:
    """Validate a single configuration file."""
    filepath = config_dir / filename
    errors = []

    if not filepath.exists():
        if is_required:
            return False, [f"Required file not found: {filename}"]
        else:
            return True, []  # Optional file not found is OK

    try:
        config = load_yaml(filepath)
    except yaml.YAMLError as e:
        return False, [f"YAML parse error in {filename}: {e}"]
    except Exception as e:
        return False, [f"Error reading {filename}: {e}"]

    if config is None:
        return False, [f"File is empty: {filename}"]

    # Check required keys
    for keys in required_paths:
        if isinstance(keys, str):
            keys = [keys]
        valid, msg = has_keys(config, keys)
        if not valid:
            errors.append(f"{filename}: {msg}")

    # Run specific validators
    if filename == "platform.yaml":
        errors.extend(validate_platform_config(config))
    elif filename == "connectors.yaml":
        errors.extend(validate_connectors_config(config))
    elif filename == "products.yaml":
        errors.extend(validate_products_config(config))

    return len(errors) == 0, errors


def main() -> int:
    """Main validation function."""
    config_dir = get_config_dir()

    if not config_dir.exists():
        print(f"[ERROR] Config directory not found: {config_dir}")
        return 1

    print(f"Validating configuration in: {config_dir}")
    print("-" * 50)

    all_errors = []
    all_valid = True

    # Validate required files
    for filename, required_paths in REQUIRED_FILES:
        valid, errors = validate_file(config_dir, filename, [required_paths], is_required=True)
        if valid:
            print(f"[OK]   {filename}")
        else:
            print(f"[FAIL] {filename}")
            all_valid = False
            all_errors.extend(errors)

    # Validate optional files
    for filename, required_paths in OPTIONAL_FILES:
        valid, errors = validate_file(config_dir, filename, [required_paths], is_required=False)
        if valid:
            filepath = config_dir / filename
            if filepath.exists():
                print(f"[OK]   {filename}")
            else:
                print(f"[SKIP] {filename} (optional, not present)")
        else:
            print(f"[FAIL] {filename}")
            all_valid = False
            all_errors.extend(errors)

    print("-" * 50)

    if all_errors:
        print("\nErrors found:")
        for error in all_errors:
            print(f"  - {error}")
        print()

    if all_valid:
        print("[OK] Configuration validation passed")
        return 0
    else:
        print("[FAIL] Configuration validation failed")
        return 2


if __name__ == "__main__":
    sys.exit(main())
