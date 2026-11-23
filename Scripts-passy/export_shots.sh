#!/bin/bash
# usage: export_shots.sh <xcresult> <destdir>   exports the named screenshot attachments as PNG
source "$(dirname "$0")/env.sh"
src=$(mktemp -d "$PASSY_SCRATCH/exp.XXXXXX"); mkdir -p "$2"
xcrun xcresulttool export attachments --path "$1" --output-path "$src" >/dev/null 2>&1
python3 - "$2" "$src" <<'P'
import json,sys,shutil,re
d,src=sys.argv[1],sys.argv[2]; m=json.load(open(src+'/manifest.json'))
for t in m:
    for a in t.get('attachments',[]):
        n=re.sub(r'_\d+_[0-9A-F-]{36}','',a.get('suggestedHumanReadableName','')).rsplit('.',1)[0]
        shutil.copy(src+'/'+a['exportedFileName'], f'{d}/{n}.png'); print(n)
P
rm -rf "$src"
