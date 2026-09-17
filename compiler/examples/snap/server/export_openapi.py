"""Generate route/input/auth schema without touching persistent application data."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from snap_service.main import create_app

with TemporaryDirectory() as folder:
    document = create_app(Path(folder) / 'schema.sqlite3', rate_limit=False).openapi()
Path(__file__).with_name('openapi.json').write_text(json.dumps(document, indent=2, sort_keys=True) + '\n')
