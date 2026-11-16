import re,sys,json,glob
LIT = re.compile(r"""(?:\bText\(\s*(?:const\s+)?|\b(?:labelText|hintText|tooltip|label|title|content|helperText)\s*:\s*(?:const\s+)?(?:Text\(\s*(?:const\s+)?)?)(['"])((?:\.|(?!\1).)*?)\1""")
out={}
for p in sys.argv[1:]:
    s=open(p,encoding="utf8").read()
    seen=[]
    for m in LIT.finditer(s):
        t=m.group(2)
        if re.search(r"[A-Za-z]{3}",t) and "$" not in t and "\n" not in t and t not in seen:
            seen.append(t)
    out[p]=seen
print(json.dumps(out,ensure_ascii=False,indent=1))
