# fold-il2cpp-dump.py
#
# il2cpp_dump.json is 1.12 GB of pretty-printed JSON and is regenerable from
# REFramework at any time, so it should not live on disk forever. But it holds
# the one thing sdk_ida's headers do NOT: METHOD names and return types.
# sdk_ida gives fields and byte offsets; every "which overload do I call"
# question this project has hit -- getItem, getNPCData, getAllCharacters --
# is a method question.
#
# So: stream it line by line (it will not fit in memory), keep the app.* and
# via.* surface, and write one grep-able TSV. Then the 1.12 GB can go.
#
#   python tools\fold-il2cpp-dump.py
#
# Output: reference\dd2-types.tsv   TYPE <tab> KIND <tab> NAME <tab> DETAIL
import io, os, re, sys, time

SRC = r'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\il2cpp_dump.json'
OUT_DIR = r'D:\dd2-forge\reference'
OUT = os.path.join(OUT_DIR, 'dd2-types.tsv')

KEEP = ('app.', 'via.')          # the namespaces this project actually calls

re_type    = re.compile(r'^    "(.+?)": \{$')
re_section = re.compile(r'^        "(\w+)": [\{\[]$')
re_entry   = re.compile(r'^            "(.*?)": \{$')
re_kv      = re.compile(r'^\s+"(\w+)": "(.*?)",?$')
# numbers are unquoted; we need "id" because the dict key is name+id, and the
# id has to come off or every method reads like ".cctor305298"
re_num     = re.compile(r'^\s+"(id)": (\d+),?$')

os.makedirs(OUT_DIR, exist_ok=True)

cur_type = None
keep     = False
section  = None
entry    = None
pending  = {}
counts   = {'type': 0, 'kept': 0, 'method': 0, 'field': 0, 'prop': 0}
sample   = []
started  = time.time()

def flush(w):
    """Write whatever the just-closed entry collected."""
    global pending, entry
    if not (keep and cur_type and entry is not None):
        pending = {}
        return
    if section == 'methods':
        # The dict KEY is the method name. "function" is the address of the
        # compiled code, which is useless here and was silently winning this
        # fallback -- the first run emitted 341,300 rows of hex addresses.
        name = entry
        mid  = pending.get('id')
        if mid and name.endswith(mid) and len(name) > len(mid):
            name = name[:-len(mid)]
        ret  = pending.get('type', '')      # returns.type lands here
        w.write('%s\tmethod\t%s\t%s\n' % (cur_type, name, ret))
        counts['method'] += 1
        if cur_type == 'app.ItemManager' and len(sample) < 12:
            sample.append('  method  %s -> %s' % (name, ret))
    elif section == 'fields':
        w.write('%s\tfield\t%s\t%s\n' % (cur_type, entry, pending.get('type', '')))
        counts['field'] += 1
    elif section == 'properties':
        g = pending.get('getter', '')
        s = pending.get('setter', '')
        w.write('%s\tprop\t%s\t%s%s\n' % (cur_type, entry, g, ('/' + s) if s else ''))
        counts['prop'] += 1
        if cur_type == 'app.ItemManager' and len(sample) < 12:
            sample.append('  prop    %s  get=%s set=%s' % (entry, g, s))
    pending = {}

with io.open(SRC, 'r', encoding='utf-8', errors='replace') as f, \
     io.open(OUT, 'w', encoding='utf-8', newline='\n') as w:
    w.write('# generated from il2cpp_dump.json -- TYPE\\tKIND\\tNAME\\tDETAIL\n')
    for line in f:
        m = re_type.match(line)
        if m:
            flush(w)
            cur_type = m.group(1)
            keep = cur_type.startswith(KEEP)
            section = None
            entry = None
            counts['type'] += 1
            if keep:
                counts['kept'] += 1
            continue
        if not keep:
            continue
        m = re_section.match(line)
        if m:
            flush(w)
            section = m.group(1)
            entry = None
            continue
        if section in ('methods', 'fields', 'properties'):
            m = re_entry.match(line)
            if m:
                flush(w)
                entry = m.group(1)
                continue
            m = re_num.match(line)
            if m and entry is not None and 'id' not in pending:
                pending['id'] = m.group(2)
                continue
            m = re_kv.match(line)
            if m and entry is not None:
                k, v = m.group(1), m.group(2)
                if k in ('function', 'type', 'getter', 'setter'):
                    # returns.type appears after function; do not let a
                    # field's own "type" clobber a method's return type
                    if k != 'type' or 'type' not in pending:
                        pending[k] = v
    flush(w)

size = os.path.getsize(OUT)
print('read   %s' % SRC)
print('types  %d seen, %d kept (%s)' % (counts['type'], counts['kept'], ' / '.join(KEEP)))
print('rows   %d methods, %d fields, %d properties' % (counts['method'], counts['field'], counts['prop']))
print('wrote  %s  (%s bytes, %.1f MB)' % (OUT, format(size, ','), size / 1048576.0))
print('took   %.1fs' % (time.time() - started))
print('--- sample: app.ItemManager ---')
print('\n'.join(sample) if sample else '  (app.ItemManager produced no rows -- PARSER IS WRONG)')
