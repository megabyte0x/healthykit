"""Build an allowlisted Docker context with the same upstream backend source, no secrets."""
from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parents[1]
target = Path(sys.argv[1]).resolve()
if target.exists():
    raise SystemExit('Choose a new empty build-context directory')
target.mkdir(parents=True)
service = root / 'cloudrun/health-sync-api'
for name in ('app.py','models.py','main.py','remote_mcp.py','oauth_store.py','official_storage.py',
             'Dockerfile','.dockerignore','requirements.txt'):
    shutil.copy2(service/name, target/name)
# No repository history, env, caches, migrations, samples or private files enter the image.
for source in (root/'backend').glob('*.py'):
    out=target/'backend'/source.name
    out.parent.mkdir(exist_ok=True)
    shutil.copy2(source,out)
print(target)
