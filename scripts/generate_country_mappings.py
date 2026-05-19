#!/usr/bin/env python3
"""
Parses Okta group rules YAML and extracts Okta group → country code mappings.
Country codes are read exclusively from rule expressions (user.countryCode == "XX").
Groups whose rules have no expression-based country checks are omitted.

Output is written to <output_dir>/<env>.json as:
  { "<OktaGroupName>": ["CC", ...] }

Usage: python3 scripts/generate_country_mappings.py <env> <output_dir>
"""
import json
import re
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent


def extract_countries_from_expression(expression: str) -> list[str]:
    """Extract 2-letter country codes from Okta expression language."""
    if not expression:
        return []
    matches = re.findall(r'user\.countryCode\s*==\s*"([A-Z]{2})"', expression)
    seen = set()
    return [cc for cc in matches if not (cc in seen or seen.add(cc))]


def load_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open(encoding='utf-8') as f:
        return yaml.safe_load(f) or {}


def build_group_country_map(env: str) -> dict[str, list[str]]:
    common = load_yaml(REPO_ROOT / 'settings/group_rules/_common.yaml')
    env_rules = load_yaml(REPO_ROOT / f'settings/group_rules/{env}.yaml')
    all_rules = {**common, **env_rules}

    group_countries: dict[str, set[str]] = {}

    for rule in all_rules.values():
        if not isinstance(rule, dict) or 'target groups' not in rule:
            continue

        expression = rule.get('expression', '') or ''
        from_expression = extract_countries_from_expression(expression)

        for group in rule['target groups']:
            countries = from_expression
            if not countries:
                continue
            group_countries.setdefault(group, set()).update(countries)

    return {
        group: sorted(codes)
        for group, codes in sorted(group_countries.items())
    }


def main() -> None:
    if len(sys.argv) != 3:
        print('Usage: python3 scripts/generate_country_mappings.py <env> <output_dir>')
        sys.exit(1)

    env, output_dir = sys.argv[1], Path(sys.argv[2])
    result = build_group_country_map(env)

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f'{env}.json'
    output_path.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f'Written {len(result)} group mappings to {output_path}')


if __name__ == '__main__':
    main()
