#!/usr/bin/env python3

import re
from pathlib import Path
import matplotlib.pyplot as plt
from Bio import Phylo
from io import StringIO


def extract_newick_from_paup(path):
    """
    Extract the first Newick tree from a PAUP NEXUS tree file.
    Handles optional annotations like: tree 'X' = [&U] (...);
    """
    text = Path(path).read_text()

    # Find "tree ... = ..." then capture from the first "(" up to the first ";" after it
    m = re.search(r"^\s*tree\b.*?=\s*(?:\[[^\]]*\]\s*)?(\(.*?;)\s*$",
                  text,
                  flags=re.IGNORECASE | re.MULTILINE | re.DOTALL)

    if m:
        return m.group(1)

    # Fallback: capture any Newick-looking substring "(...);"
    m2 = re.search(r"(\(.*?;)", text, flags=re.DOTALL)
    if m2:
        return m2.group(1)

    raise ValueError(f"No Newick tree found inside {path}")


def load_tree(path):
    """
    Load tree from PAUP .tre file.
    """
    newick = extract_newick_from_paup(path)
    handle = StringIO(newick)
    return Phylo.read(handle, "newick")


def render_tree(tree, title, out_pdf, out_png):
    fig = plt.figure(figsize=(10, 12))
    ax = fig.add_subplot(1, 1, 1)

    Phylo.draw(tree, do_show=False, axes=ax)

    ax.set_title(title)

    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)

    plt.close(fig)


def main():

    tree_dir = Path("data/trees")
    report_dir = Path("data/reports")
    fig_dir = report_dir / "figures"

    fig_dir.mkdir(parents=True, exist_ok=True)

    tree_files = [
        tree_dir / "clustalw_parsimony.tre",
        tree_dir / "clustalw_nj.tre",
        tree_dir / "mafft_parsimony.tre",
        tree_dir / "mafft_nj.tre",
        tree_dir / "muscle_parsimony.tre",
        tree_dir / "muscle_nj.tre",
        report_dir / "consensus.tre",
    ]

    print(f"Rendering {len(tree_files)} trees to: {fig_dir}")

    for tree_path in tree_files:

        if not tree_path.exists():
            raise FileNotFoundError(tree_path)

        tree = load_tree(tree_path)

        out_pdf = fig_dir / f"{tree_path.stem}.pdf"
        out_png = fig_dir / f"{tree_path.stem}.png"

        render_tree(tree, tree_path.name, out_pdf, out_png)

        print(f"✓ {tree_path.name}")

    print("\nAll figures exported.")


if __name__ == "__main__":
    main()