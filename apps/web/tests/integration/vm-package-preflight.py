"""Read-only source archive gate; never extracts, deploys or connects to SQL/SMTP."""
import argparse
import hashlib
import io
import json
import posixpath
import re
import shutil
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {
    'index.html', 'api/server.js', 'api/production-start.cjs', 'api/package.json',
    'api/package-lock.json', 'api/routes/account.js', 'api/services/account.js',
    'api/services/transactional-mail.js', 'api/security/production-config.js',
    'app/recover.html', 'app/js/account-recovery.js',
    'app/vendor/occt-import-js/occt-import-js.wasm',
}


def require(condition, code):
    if not condition:
        raise ValueError(code)


def digest(stream):
    result = hashlib.sha256()
    while chunk := stream.read(65536):
        result.update(chunk)
    return result.hexdigest()


def inspect_archive(archive, source_root=None):
    archive = Path(archive)
    require(not archive.is_symlink() and archive.is_file(), 'ARCHIVE_NOT_REGULAR')
    require(archive.stat().st_size <= 128 * 1024 * 1024, 'ARCHIVE_TOO_LARGE')
    with archive.open('rb') as stream:
        archive_hash = digest(stream)
    checksum_path = Path(str(archive) + '.sha256')
    require(checksum_path.is_file() and not checksum_path.is_symlink() and checksum_path.stat().st_size <= 1024, 'CHECKSUM_FILE_INVALID')
    checksum = checksum_path.read_text(encoding='utf-8').strip()
    require(checksum == archive_hash + '  ' + archive.name, 'ARCHIVE_CHECKSUM_MISMATCH')
    list_path = Path(str(archive) + '.files')
    require(list_path.is_file() and not list_path.is_symlink() and list_path.stat().st_size <= 2 * 1024 * 1024, 'LIST_INVALID')
    listing = list_path.read_bytes()
    require(listing.endswith(b'\0'), 'LIST_INVALID')
    expected = listing[:-1].decode('utf-8').split('\0')
    require(len(expected) == len(set(expected)), 'LIST_DUPLICATE')
    source_root = Path(source_root).resolve(strict=True) if source_root else None
    files, texts, total = {}, {}, 0
    with tarfile.open(archive, 'r:gz') as bundle:
        for member in bundle:
            name = member.name
            require(len(files) < 1000, 'TOO_MANY_FILES')
            require(member.isreg() and not member.issparse(), 'NON_REGULAR_MEMBER')
            require(re.fullmatch(r'(?:index\.html|app/[a-zA-Z0-9_./ ()-]+|api/[a-zA-Z0-9_./-]+)', name), 'PATH_REJECTED')
            parts = name.split('/')
            require(not any(p in ('', '..', 'node_modules', 'dist', 'trash') or p.startswith('.') for p in parts), 'PATH_REJECTED')
            require(re.search(r'\.(?:html|css|js|cjs|json|sql|wasm|png|jpg|jpeg|svg|webp|ico|woff|woff2)$', name, re.I)
                    or re.fullmatch(r'app/vendor/occt-import-js/license[.a-z-]*\.txt', name), 'FILE_TYPE_REJECTED')
            require(name not in files, 'DUPLICATE_MEMBER')
            require(0 <= member.size <= 64 * 1024 * 1024, 'MEMBER_TOO_LARGE')
            total += member.size
            require(total <= 256 * 1024 * 1024, 'PACKAGE_TOO_LARGE')
            with bundle.extractfile(member) as stream:
                sha = digest(stream)
            files[name] = {'path': name, 'sha256': sha}
            if name.endswith(('.js', '.cjs', '.json')):
                require(member.size <= 2 * 1024 * 1024, 'SOURCE_TOO_LARGE')
                with bundle.extractfile(member) as stream:
                    texts[name] = stream.read().decode('utf-8-sig')
            if source_root:
                source = source_root.joinpath(*parts)
                require(source.resolve(strict=True) == source, 'SOURCE_ALIAS_REJECTED')
                require(source.is_file(), 'SOURCE_NOT_REGULAR')
                with source.open('rb') as stream:
                    require(digest(stream) == sha, 'SOURCE_HASH_MISMATCH')
    require(set(files) == set(expected), 'ARCHIVE_LIST_MISMATCH')
    require(REQUIRED <= files.keys(), 'REQUIRED_SOURCE_MISSING')
    manifest = json.loads(texts['api/package.json'])
    lock = json.loads(texts['api/package-lock.json'])
    require(manifest['dependencies'] == lock['packages']['']['dependencies'], 'PACKAGE_LOCK_MISMATCH')
    version = manifest['dependencies'].get('nodemailer', '')
    package = lock['packages'].get('node_modules/nodemailer', {})
    require(re.fullmatch(r'\d+\.\d+\.\d+', version) and package.get('version') == version
            and package.get('integrity', '').startswith('sha512-'), 'SMTP_DEPENDENCY_NOT_LOCKED')
    # Resolve only literal local CommonJS imports, without executing archive code.
    pending, reached = ['api/production-start.cjs'], set()
    while pending:
        current = pending.pop()
        if current in reached:
            continue
        reached.add(current)
        for target in re.findall(r'require\s*\(\s*[\'"](\.[^\'"]+)[\'"]\s*\)', texts.get(current, '')):
            base = posixpath.normpath(posixpath.join(posixpath.dirname(current), target))
            require(not base.startswith('../') and not base.startswith('/'), 'MODULE_OUTSIDE_PACKAGE')
            candidates = [base, base + '.js', base + '.cjs', base + '.json', base + '/index.js']
            resolved = next((item for item in candidates if item in files), None)
            require(resolved is not None, 'LOCAL_MODULE_MISSING')
            pending.append(resolved)
    return {'archiveSha256': archive_hash, 'files': [files[k] for k in sorted(files)],
            'uncompressedBytes': total, 'reachableLocalModules': len(reached)}


class GateTests(unittest.TestCase):
    def setUp(self):
        self.runtime = ROOT / 'tests' / '.runtime'
        self.runtime.mkdir(exist_ok=True)
        self.work = Path(tempfile.mkdtemp(prefix='vm-package-tests-', dir=self.runtime)).resolve()
        self.archive = self.work / 'fixture.tar.gz'

    def tearDown(self):
        require(self.work.parent == self.runtime.resolve() and self.work.name.startswith('vm-package-tests-'), 'TEST_CLEANUP_REJECTED')
        shutil.rmtree(self.work)

    def fixture(self, extra=None, missing=None, bad_import=False):
        data = {p: b'' for p in REQUIRED if p != missing}
        data['api/package.json'] = b'{"dependencies":{"nodemailer":"1.2.3"}}'
        data['api/package-lock.json'] = json.dumps({'packages': {'': {'dependencies': {'nodemailer': '1.2.3'}},
            'node_modules/nodemailer': {'version': '1.2.3', 'integrity': 'sha512-synthetic-test-only'}}}).encode()
        data['api/production-start.cjs'] = b'require("./missing");' if bad_import else b'require("./server");'
        with tarfile.open(self.archive, 'w:gz') as bundle:
            for name, content in data.items():
                item = tarfile.TarInfo(name); item.size = len(content)
                bundle.addfile(item, io.BytesIO(content))
            if extra:
                bundle.addfile(extra)
        names = list(data) + ([extra.name] if extra else [])
        Path(str(self.archive) + '.files').write_bytes(('\0'.join(names) + '\0').encode())
        with self.archive.open('rb') as stream:
            Path(str(self.archive) + '.sha256').write_text(digest(stream) + '  ' + self.archive.name + '\n', encoding='utf-8')

    def test_accepts_locked_source_package(self):
        self.fixture(); self.assertEqual(len(inspect_archive(self.archive)['files']), len(REQUIRED))

    def test_rejects_traversal_without_extracting(self):
        self.fixture(tarfile.TarInfo('../escape.js'))
        with self.assertRaisesRegex(ValueError, 'PATH_REJECTED'): inspect_archive(self.archive)
        self.assertFalse((self.work.parent / 'escape.js').exists())

    def test_rejects_symlink_without_following(self):
        item = tarfile.TarInfo('app/escape.js'); item.type = tarfile.SYMTYPE; item.linkname = '../../escape.js'
        self.fixture(item)
        with self.assertRaisesRegex(ValueError, 'NON_REGULAR_MEMBER'): inspect_archive(self.archive)

    def test_rejects_changed_checksum(self):
        self.fixture(); Path(str(self.archive) + '.sha256').write_text('0' * 64 + '  ' + self.archive.name, encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'ARCHIVE_CHECKSUM_MISMATCH'): inspect_archive(self.archive)

    def test_rejects_missing_dependency_source(self):
        self.fixture(bad_import=True)
        with self.assertRaisesRegex(ValueError, 'LOCAL_MODULE_MISSING'): inspect_archive(self.archive)

    def test_rejects_missing_cad_runtime(self):
        self.fixture(missing='app/vendor/occt-import-js/occt-import-js.wasm')
        with self.assertRaisesRegex(ValueError, 'REQUIRED_SOURCE_MISSING'): inspect_archive(self.archive)

    def test_rejects_private_environment_file(self):
        self.fixture(tarfile.TarInfo('api/.env'))
        with self.assertRaisesRegex(ValueError, 'PATH_REJECTED'): inspect_archive(self.archive)

    def test_compares_the_actual_source_bytes(self):
        self.fixture(); source = self.work / 'source'
        with tarfile.open(self.archive) as bundle:
            for member in bundle:
                target = source.joinpath(*member.name.split('/'))
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(bundle.extractfile(member).read())
        self.assertEqual(len(inspect_archive(self.archive, source)['files']), len(REQUIRED))
        (source / 'api' / 'server.js').write_bytes(b'changed source')
        with self.assertRaisesRegex(ValueError, 'SOURCE_HASH_MISMATCH'): inspect_archive(self.archive, source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', nargs='?'); parser.add_argument('--release')
    parser.add_argument('--source-root'); parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(GateTests))
        return 0 if result.wasSuccessful() else 1
    require(args.archive and args.release and re.fullmatch(r'web-\d{4}-\d{2}-\d{2}-\d{2}', args.release), 'RELEASE_ARGUMENT_REQUIRED')
    result = inspect_archive(args.archive, args.source_root)
    manifest = {'release': args.release, **result, 'liveDeploymentVerified': False}
    output = Path(str(args.archive) + '.manifest.json')
    with output.open('x', encoding='utf-8') as stream:
        json.dump(manifest, stream, indent=2); stream.write('\n')
    print(json.dumps({'status': 'PACKAGE_VERIFIED_OFFLINE', 'manifest': str(output), 'files': len(result['files']),
                      'archiveSha256': result['archiveSha256'], 'reachableLocalModules': result['reachableLocalModules'], 'liveDeploymentVerified': False}))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, tarfile.TarError, UnicodeError) as error:
        code = str(error) if re.fullmatch(r'[A-Z_]+', str(error)) else 'INVALID_PACKAGE'
        print('PACKAGE_VERIFICATION_FAILED ' + code); raise SystemExit(1)
