#!/usr/bin/env python3
"""Готовит PKGBUILD для Arch Linux из packaging/arch/PKGBUILD.in.

Подставляет версию из тега и sha256 Linux-архива из dist/ и кладёт PKGBUILD
в dist/, откуда он уходит в релиз. Ставится он потом так:
    curl -LO https://github.com/vyto4ka/vysh/releases/latest/download/PKGBUILD
    makepkg -si

Запуск в CI:  TAG=v0.3.3 python3 tools/release/make_pkgbuild.py dist
"""
import hashlib
import os
import pathlib
import sys

tag = os.environ["TAG"]
version = tag.lstrip("v")
dist = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "dist")

# pacman не принимает дефис в pkgver: 0.4.0-beta.1 -> 0.4.0beta.1
pkgver = version.replace("-", "")

archive = dist / f"vysh-{tag}-linux-x64.tar.gz"
if not archive.exists():
    sys.exit(f"нет {archive}: Linux-сборка не попала в dist/")

sha = hashlib.sha256(archive.read_bytes()).hexdigest()
template = pathlib.Path("packaging/arch/PKGBUILD.in").read_text(encoding="utf-8")
pkgbuild = template.replace("@PKGVER@", pkgver).replace("@SHA256@", sha)

if "-" in version:
    # Для предрелиза имя файла в URL и pkgver расходятся.
    pkgbuild = pkgbuild.replace(
        "releases/download/v${pkgver}/vysh-v${pkgver}-linux-x64.tar.gz",
        f"releases/download/{tag}/vysh-{tag}-linux-x64.tar.gz",
    )

(dist / "PKGBUILD").write_text(pkgbuild, encoding="utf-8")
print(f"PKGBUILD {pkgver}, sha256 {sha}")
