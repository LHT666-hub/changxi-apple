"""Download a GitHub Actions artifact with bounded network timeouts."""
import io
import json
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

artifact_id, destination = sys.argv[1:3]
token = subprocess.check_output(['gh', 'auth', 'token'], text=True).strip()
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None
opener = urllib.request.build_opener(NoRedirect)
request = urllib.request.Request(
    f'https://api.github.com/repos/LHT666-hub/changxi-apple/actions/artifacts/{artifact_id}/zip',
    headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'})
try:
    response = opener.open(request, timeout=20)
    location = response.headers.get('Location')
except urllib.error.HTTPError as error:
    if error.code != 302:
        print(f'Artifact API returned HTTP {error.code}')
        sys.exit(1)
    location = error.headers['Location']
del token
try:
    with urllib.request.urlopen(location, timeout=30) as response:
        content = response.read()
    root = Path(destination).resolve()
    root.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        for info in archive.infolist():
            target = (root / info.filename).resolve()
            if not target.is_relative_to(root):
                raise ValueError('Artifact contains an invalid path')
        archive.extractall(root)
    print(f'Downloaded {len(content)} bytes to {root}')
except Exception as error:
    print(f'Artifact download failed: {type(error).__name__}')
    sys.exit(1)
