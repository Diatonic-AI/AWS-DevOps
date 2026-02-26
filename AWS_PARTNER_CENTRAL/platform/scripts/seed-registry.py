#!/usr/bin/env python3
"""
Module registry seeding script for Partner Central Wrapper Platform.
Seeds the module catalog into the control plane database.
"""

import sys
import os
import json
from pathlib import Path
from datetime import datetime
import uuid

try:
    import yaml
except ImportError:
    print("[ERROR] PyYAML not installed. Run: pip install pyyaml")
    sys.exit(1)


def get_registry_dir() -> Path:
    """Get the registry directory path."""
    script_dir = Path(__file__).parent
    registry_dir = script_dir.parent / "registry"
    return registry_dir


def load_catalog(registry_dir: Path) -> dict:
    """Load the module catalog from JSON or example file."""
    catalog_file = registry_dir / "module-catalog.json"
    example_file = registry_dir / "module-catalog.example.json"

    if catalog_file.exists():
        with open(catalog_file) as f:
            return json.load(f)
    elif example_file.exists():
        print(f"[INFO] Using example catalog: {example_file}")
        with open(example_file) as f:
            return json.load(f)
    else:
        raise FileNotFoundError("No module catalog found")


def validate_module(module: dict, schema: dict) -> list[str]:
    """Validate a module against the schema."""
    errors = []

    # Check required fields
    required = ["apiVersion", "kind", "metadata", "spec"]
    for field in required:
        if field not in module:
            errors.append(f"Missing required field: {field}")

    if "metadata" in module:
        meta = module["metadata"]
        for field in ["name", "version", "description"]:
            if field not in meta:
                errors.append(f"Missing metadata.{field}")

    if "spec" in module:
        spec = module["spec"]
        if "type" not in spec:
            errors.append("Missing spec.type")
        if "tenancy" not in spec:
            errors.append("Missing spec.tenancy")

    return errors


def generate_sql_inserts(modules: list[dict]) -> str:
    """Generate SQL INSERT statements for modules."""
    statements = []
    statements.append("-- Module Registry Seed Data")
    statements.append(f"-- Generated: {datetime.utcnow().isoformat()}Z")
    statements.append("")
    statements.append("BEGIN;")
    statements.append("")

    for module in modules:
        meta = module.get("metadata", {})
        spec = module.get("spec", {})

        module_id = str(uuid.uuid4())
        name = meta.get("name", "unknown")
        version = meta.get("version", "0.0.0")
        description = meta.get("description", "").replace("'", "''")
        module_type = spec.get("type", "unknown")

        # JSON encode the full spec
        spec_json = json.dumps(spec).replace("'", "''")

        sql = f"""INSERT INTO module_registry (id, name, version, description, type, spec_json, status, created_at)
VALUES (
  '{module_id}',
  '{name}',
  '{version}',
  '{description}',
  '{module_type}',
  '{spec_json}'::jsonb,
  'active',
  NOW()
) ON CONFLICT (name, version) DO UPDATE SET
  description = EXCLUDED.description,
  spec_json = EXCLUDED.spec_json,
  updated_at = NOW();
"""
        statements.append(sql)

    statements.append("COMMIT;")
    return "\n".join(statements)


def generate_json_output(modules: list[dict]) -> str:
    """Generate JSON output for API seeding."""
    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "modules": []
    }

    for module in modules:
        meta = module.get("metadata", {})
        spec = module.get("spec", {})

        output["modules"].append({
            "id": str(uuid.uuid4()),
            "name": meta.get("name"),
            "version": meta.get("version"),
            "description": meta.get("description"),
            "type": spec.get("type"),
            "spec": spec,
            "status": "active"
        })

    return json.dumps(output, indent=2)


def main() -> int:
    """Main seeding function."""
    import argparse

    parser = argparse.ArgumentParser(description="Seed module registry")
    parser.add_argument(
        "--format", "-f",
        choices=["sql", "json"],
        default="sql",
        help="Output format (default: sql)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file (default: stdout)"
    )
    parser.add_argument(
        "--validate-only", "-v",
        action="store_true",
        help="Only validate, don't generate output"
    )

    args = parser.parse_args()

    registry_dir = get_registry_dir()

    try:
        catalog = load_catalog(registry_dir)
    except FileNotFoundError as e:
        print(f"[ERROR] {e}")
        return 1

    modules = catalog.get("catalog", {}).get("modules", [])

    if not modules:
        print("[ERROR] No modules found in catalog")
        return 1

    print(f"[INFO] Found {len(modules)} modules in catalog")

    # Load schema for validation
    schema_file = registry_dir / "module-registry.schema.json"
    schema = {}
    if schema_file.exists():
        with open(schema_file) as f:
            schema = json.load(f)

    # Validate all modules
    all_valid = True
    for module in modules:
        name = module.get("metadata", {}).get("name", "unknown")
        errors = validate_module(module, schema)
        if errors:
            print(f"[FAIL] {name}:")
            for error in errors:
                print(f"       - {error}")
            all_valid = False
        else:
            print(f"[OK]   {name}")

    if not all_valid:
        print("\n[ERROR] Validation failed")
        return 2

    if args.validate_only:
        print("\n[OK] All modules valid")
        return 0

    # Generate output
    if args.format == "sql":
        output = generate_sql_inserts(modules)
    else:
        output = generate_json_output(modules)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"\n[OK] Output written to {args.output}")
    else:
        print("\n" + "=" * 50)
        print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
