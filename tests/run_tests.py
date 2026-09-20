#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_tests.py — tests de NeoDOS sur cible (Phosphoneo headless).

Chaque cas est un fichier tests/cases/NOM.keys : le texte tapé au clavier,
une commande par ligne (Entrée à la fin de chaque ligne ; une ligne terminée
par « \\c » est frappée sans Entrée, pour répondre à « Y/N » par exemple ;
les séquences \\u \\d \\l \\r \\h \\k \\x \\b \\e sont les touches d'édition du typer
Phosphoneo, \\t la touche Tab, \\1..\\8 les touches F1..F8 ; les autres antislashs
sont des séparateurs DOS — éviter donc les chemins en minuscules commençant
par une de ces lettres). Le résultat attendu est tests/expected/NOM.txt :
  - la console (53x30) après exécution, lignes vides et espaces de fin
    retirés, à partir de la ligne « NeoDOS version » ;
  - facultativement une section « --- files --- » : liste triée des fichiers
    du stockage après le test (chemins relatifs, « / » final pour un dossier).

Le stockage de chaque test est une copie fraîche de tests/fixtures/ plus les
exemples de storage/ (HELLO.NEO, AUTOEXEC.BAT, DEMO.BAT) et boot/neodos.neo (stub).

Usage : run_tests.py [--ref] [NOM ...]
  --ref  régénère les fichiers attendus au lieu de comparer
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOS = os.environ.get("PHOSPHONEO", os.path.expanduser("~/Phosphoneo/build/phosphoneo"))
NEO = os.path.join(ROOT, "build", "neodos.neo")
CASES = os.path.join(ROOT, "tests", "cases")
EXPECTED = os.path.join(ROOT, "tests", "expected")
FIXTURES = os.path.join(ROOT, "tests", "fixtures")
STORAGE = os.path.join(ROOT, "storage")

START_CYCLES = 3_000_000        # NeoDOS a affiché son invite
CYCLES_PER_KEY = 700_000        # typer Phosphoneo : 6 trames par touche
TAIL_CYCLES = 8_000_000         # marge pour la dernière commande


def build_storage(tmp):
    for src in (FIXTURES, STORAGE):
        if os.path.isdir(src):
            shutil.copytree(src, tmp, dirs_exist_ok=True)
    os.makedirs(os.path.join(tmp, "boot"), exist_ok=True)   # rechargement par le stub
    shutil.copy(NEO, os.path.join(tmp, "boot", "neodos.neo"))
    gitkeep = os.path.join(tmp, ".gitkeep")
    if os.path.exists(gitkeep):
        os.remove(gitkeep)


def list_files(root):
    out = []
    for d, dirs, files in os.walk(root):
        if "boot" in dirs:
            dirs.remove("boot")                 # boot/neodos.neo : hors listing
        rel = os.path.relpath(d, root)
        rel = "" if rel == "." else rel + "/"
        for x in dirs:
            out.append(rel + x + "/")
        for x in files:
            out.append(rel + x)
    return sorted(out)


def normalise(text):
    lines = [l.rstrip() for l in text.splitlines()]
    lines = [l for l in lines if l]
    for i, l in enumerate(lines):
        if l.startswith("NeoDOS version"):
            return lines[i:]
    return lines


def run_case(name, ref):
    keys = open(os.path.join(CASES, name + ".keys"), encoding="utf-8").read()
    keys = keys.rstrip("\n").replace("\\c\n", "")   # « \c » en fin de ligne : pas d'Entrée
    nkeys = len(keys) + 1
    # séquences du typer conservées (\u \d \l \r flèches, \h \k Début/Fin, \x Suppr,
    # \b Retour arrière, \e Échap, \t Tab, \1..\8, \n) ; tout autre « \ » est un antislash DOS
    import re
    keys = re.sub(r"\\(?![udlrhkxbze1-8nt])", r"\\\\", keys).replace("\n", "\\n") + "\\n"
    keys = keys.replace("\\t", "\t")             # « \t » : touche Tab (caractère tabulation)
    cycles = START_CYCLES + CYCLES_PER_KEY * nkeys + TAIL_CYCLES
    tmp = tempfile.mkdtemp(prefix="neodos-" + name + "-")
    try:
        build_storage(tmp)
        out = os.path.join(tmp, "console.txt")
        cmd = [PHOS, NEO, "--storage", tmp, "--cycles", str(cycles),
               "--type-keys", "%d:%s" % (START_CYCLES, keys),
               "--screenshot-text", out]
        # NOM.api : groupes API à journaliser (ex. « 5 ») ; la référence reçoit
        # la liste des fonctions distinctes appelées (programme graphique lancé…)
        api_path = os.path.join(CASES, name + ".api")
        api_log = None
        if os.path.exists(api_path):
            api_log = os.path.join(tmp, "api.log")
            groups = open(api_path).read().strip()
            cmd += ["--api-log", "%s:%s" % (api_log, groups)]
        r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                           timeout=600, text=True)
        if r.returncode != 0 or not os.path.exists(out):
            print("  phosphoneo rc=%d\n%s" % (r.returncode, r.stderr[-2000:]))
            return False
        console = normalise(open(out, encoding="utf-8", errors="replace").read())
        os.remove(out)
        api = None
        if api_log:
            import re as _re
            calls = set(_re.findall(r"grp=(\d+) fn=(\d+)", open(api_log).read()))
            api = sorted("%s,%s" % c for c in calls)
            os.remove(api_log)
        files = list_files(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    exp_path = os.path.join(EXPECTED, name + ".txt")
    got = "\n".join(console) + "\n--- files ---\n" + "\n".join(files) + "\n"
    if api is not None:
        got += "--- api ---\n" + "\n".join(api) + "\n"
    if ref:
        open(exp_path, "w", encoding="utf-8").write(got)
        print("  référence écrite : %s" % os.path.relpath(exp_path, ROOT))
        return True
    if not os.path.exists(exp_path):
        print("  pas de fichier attendu (%s) — lancer avec --ref" % exp_path)
        return False
    exp = open(exp_path, encoding="utf-8").read()
    if exp == got:
        return True
    import difflib
    for l in difflib.unified_diff(exp.splitlines(), got.splitlines(),
                                  "attendu", "obtenu", lineterm=""):
        print("  " + l.encode("utf-8", "replace").decode("utf-8"))   # console binaire : pas de plantage
    return False


def main():
    args = sys.argv[1:]
    ref = "--ref" in args
    names = [a for a in args if not a.startswith("--")]
    if not names:
        names = sorted(f[:-5] for f in os.listdir(CASES) if f.endswith(".keys"))
    if not os.path.exists(PHOS):
        sys.exit("Phosphoneo introuvable : %s (variable PHOSPHONEO)" % PHOS)
    if not os.path.exists(NEO):
        sys.exit("build/neodos.neo absent : lancer make")
    ok = 0
    for name in names:
        print("[%s]" % name)
        if run_case(name, ref):
            ok += 1
            print("  OK")
        else:
            print("  ÉCHEC")
    print("%d/%d tests OK" % (ok, len(names)))
    sys.exit(0 if ok == len(names) else 1)


if __name__ == "__main__":
    main()
