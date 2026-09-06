"""Download a GitHub Actions artifact with bounded network timeouts."""
import io
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
class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.position = 0
        self.cache_start = 0
        self.cache = b''
        with urllib.request.urlopen(urllib.request.Request(url, headers={'Range': 'bytes=0-0'}), timeout=30) as response:
            content_range = response.headers.get('Content-Range')
            if not content_range:
                self.cache = response.read()
                self.length = len(self.cache)
            else:
                self.length = int(content_range.split('/')[-1])
    def seekable(self):
        return True
    def tell(self):
        return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position
    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if size <= 0:
            return b''
        if not (self.cache_start <= self.position and self.position + size <= self.cache_start + len(self.cache)):
            end = min(self.length - 1, self.position + max(size, 65536) - 1)
            for attempt in range(3):
                try:
                    req = urllib.request.Request(self.url, headers={'Range': f'bytes={self.position}-{end}'})
                    with urllib.request.urlopen(req, timeout=30) as response:
                        self.cache = response.read()
                    self.cache_start = self.position
                    break
                except Exception:
                    if attempt == 2:
                        raise
        start = self.position - self.cache_start
        result = self.cache[start:start + size]
        self.position += len(result)
        return result

try:
    root = Path(destination).resolve()
    root.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip(location)) as archive:
        selected = []
        for info in archive.infolist():
            target = (root / info.filename).resolve()
            if not target.is_relative_to(root):
                raise ValueError('Artifact contains an invalid path')
            if '.xcresult/' not in info.filename and (info.filename.endswith(('.png', 'manifest.json', '.log', '.pbxproj', '.xcscheme', '.xcworkspacedata'))):
                selected.append(info)
        selected.sort(key=lambda item: (0 if item.filename.endswith('manifest.json') else 1, item.filename))
        for info in selected:
            if (root / info.filename).exists() and (root / info.filename).stat().st_size == info.file_size:
                continue
            archive.extract(info, root)
    print(f'Downloaded {len(selected)} validation files to {root}')
except Exception as error:
    print(f'Artifact download failed: {type(error).__name__}')
    sys.exit(1)
