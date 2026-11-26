from pathlib import Path
import json,base64
root=Path(__file__).parent
names=json.loads((root.parent.parent/'assets/atlas_integration/faces-cells.json').read_text())['poses']
images={f'{family}-{name}':'data:image/png;base64,'+base64.b64encode((root/f'{family}-{name}.png').read_bytes()).decode() for name in names for family in ['cells','viruses']}
html=(root/'template.html').read_text(encoding='utf-8').replace('__IMAGES__',json.dumps(images)).replace('__EMOTIONS__',json.dumps(list(names)))
(root/'eyes.html').write_text(html,encoding='utf-8')
