import io, sys
P = r'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\il2cpp_dump.json'
want = '"app.ItemManager": {'
out, grab, n = [], False, 0
with io.open(P, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        if not grab and line.strip().startswith(want):
            grab = True
        if grab:
            out.append(line.rstrip('\n'))
            n += 1
            if n > 90:
                break
print('\n'.join(out) if out else 'app.ItemManager not found')
