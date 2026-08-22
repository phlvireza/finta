#!/usr/bin/env python3
"""Generate the localised static pages from _src/.

    python build.py

Reads _src/template.html plus one JSON locale file per language and writes a
complete, plain static HTML page for each. There is no runtime dependency and
nothing is rendered client-side -- crawlers read the initial HTML only, so
translating in the browser would make the Indonesian page invisible to search.

Run this after editing anything in _src/. Never hand-edit index.html or
id/index.html: they are outputs and the next build overwrites them.
"""

import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '_src')

# locale code -> output path relative to the site root.
# The default locale writes to the root; every other one gets a directory.
LOCALES = {
    'en': '',
    'id': 'id',
}

BANNER = (
    '<!-- GENERATED FILE - do not edit.\n'
    '     Built by build.py from _src/template.html + _src/{locale}.json.\n'
    '     Edit those and re-run `python build.py`; this file is overwritten. -->\n'
)

PLACEHOLDER = re.compile(r'\{\{(\w+)\}\}')


def load(name):
    with io.open(os.path.join(SRC, name), encoding='utf-8') as fh:
        return fh.read()


def check_parity(locales):
    """Every locale must define exactly the same keys.

    The app holds app_en.arb and app_id.arb at key parity for the same reason:
    a missing key is a page that silently renders a placeholder, and an extra
    one is dead weight nobody will ever notice.
    """
    reference = 'en'
    base = set(locales[reference])
    ok = True
    for code, strings in locales.items():
        if code == reference:
            continue
        missing = base - set(strings)
        extra = set(strings) - base
        if missing:
            print('  %s: MISSING %d key(s): %s' % (
                code, len(missing), ', '.join(sorted(missing)[:8])), file=sys.stderr)
            ok = False
        if extra:
            print('  %s: UNKNOWN %d key(s): %s' % (
                code, len(extra), ', '.join(sorted(extra)[:8])), file=sys.stderr)
            ok = False
    return ok


def render(template, strings, code):
    missing = []

    def sub(match):
        key = match.group(1)
        if key not in strings:
            missing.append(key)
            return match.group(0)
        return strings[key]

    out = PLACEHOLDER.sub(sub, template)
    if missing:
        raise SystemExit('%s: unresolved placeholder(s): %s'
                         % (code, ', '.join(sorted(set(missing)))))
    # Banner goes after the doctype so the doctype stays the first thing served.
    return out.replace('<!doctype html>\n',
                       '<!doctype html>\n' + BANNER.format(locale=code), 1)


def main():
    template = load('template.html')
    locales = {code: json.loads(load(code + '.json')) for code in LOCALES}

    print('key parity:')
    if not check_parity(locales):
        raise SystemExit('locale files are not at key parity - aborting')
    print('  ok (%d keys x %d locales)' % (len(locales['en']), len(locales)))

    for code, subdir in LOCALES.items():
        page = render(template, locales[code], code)
        out_dir = os.path.join(HERE, subdir) if subdir else HERE
        if subdir and not os.path.isdir(out_dir):
            os.makedirs(out_dir)
        path = os.path.join(out_dir, 'index.html')
        with io.open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write(page)
        rel = os.path.relpath(path, HERE).replace(os.sep, '/')
        print('wrote %-16s %6d bytes' % (rel, len(page.encode('utf-8'))))


if __name__ == '__main__':
    main()
