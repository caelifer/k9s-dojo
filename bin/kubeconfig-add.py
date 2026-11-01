#!/usr/bin/env python3
"""Merge one kwok kubeconfig into the dojo kubeconfig under AKS-style names.

usage: kubeconfig-add.py TARGET SOURCE ENV

The kwok clusters are renamed to look like AKS clusters: context and cluster
become `aks-dojo-<env>`, the user becomes
`clusterUser_rg-dojo-<env>-weu_aks-dojo-<env>`, which is the naming AKS writes
into a downloaded kubeconfig. That is what makes the k9s contexts view look like
a real multi-cluster Azure setup.
"""
import os
import sys

import yaml


def load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def replace(entries, entry):
    for index, current in enumerate(entries):
        if current.get("name") == entry["name"]:
            entries[index] = entry
            return
    entries.append(entry)


def main():
    target_path, source_path, env = sys.argv[1:4]
    cluster_name = f"aks-dojo-{env}"
    user_name = f"clusterUser_rg-dojo-{env}-weu_{cluster_name}"

    source = load(source_path)
    if not source.get("clusters"):
        sys.exit(f"{source_path}: no cluster entry")

    document = load(target_path)
    document.setdefault("apiVersion", "v1")
    document.setdefault("kind", "Config")
    document.setdefault("preferences", {})
    for section in ("clusters", "users", "contexts"):
        document.setdefault(section, [])

    source_cluster = source["clusters"][0]["cluster"]
    source_user = source["users"][0]["user"]

    replace(document["clusters"], {"name": cluster_name, "cluster": source_cluster})
    replace(document["users"], {"name": user_name, "user": source_user})
    replace(
        document["contexts"],
        {
            "name": cluster_name,
            "context": {
                "cluster": cluster_name,
                "user": user_name,
                "namespace": "default",
            },
        },
    )
    if not document.get("current-context"):
        document["current-context"] = cluster_name

    os.makedirs(os.path.dirname(target_path) or ".", exist_ok=True)
    with open(target_path, "w", encoding="utf-8") as handle:
        yaml.safe_dump(document, handle, sort_keys=False)


if __name__ == "__main__":
    main()
