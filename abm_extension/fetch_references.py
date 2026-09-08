"""Fetch pinned public inputs without credentials or changes to existing raw files."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--proxy',help='Optional HTTP proxy URL, for example http://127.0.0.1:7897')
    args=parser.parse_args()
    ref=ROOT/'reference';ref.mkdir(exist_ok=True)
    manifest=json.loads((ref/'source_manifest.json').read_text(encoding='utf-8'))
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({'https':args.proxy} if args.proxy else None))
    for record in manifest['files']:
        target=ref/record['file']
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest()==record['sha256'], f'Changed reference: {target}'
            print('Verified existing',target.name)
            continue
        data=opener.open(record['url'],timeout=120).read()
        if record['file']=='supplement.pdf':
            archive=zipfile.ZipFile(io.BytesIO(data))
            names=[name for name in archive.namelist() if name.endswith('pnas.2525760123.sapp.pdf')]
            assert len(names)==1
            data=archive.read(names[0])
        assert hashlib.sha256(data).hexdigest()==record['sha256'],f'Public input differs from pinned source: {target.name}'
        target.write_bytes(data)
        print('Downloaded and verified',target.name)
    # Extract author code for inspection, while rejecting paths outside reference/author_code.
    dest=(ref/'author_code').resolve();dest.mkdir(exist_ok=True)
    for path in ref.glob('code_*.zip'):
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                target=(dest/info.filename).resolve()
                assert target.is_relative_to(dest)
                if info.is_dir():
                    target.mkdir(parents=True,exist_ok=True)
                else:
                    data=archive.read(info)
                    if target.exists():
                        assert target.read_bytes()==data
                    else:
                        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)


if __name__=='__main__':
    main()
