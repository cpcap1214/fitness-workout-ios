"""Validate bundled offline content. Run with Python 3 and Pillow installed."""
import json
from pathlib import Path
from collections import Counter
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'Week 2' / 'Resources'
items = json.loads((root / 'exercises.json').read_text())
source = json.loads((root / 'exercise-source.json').read_text())
expected = '0025 0314 0308 0227 0662 0289 0047 0033 0577 0251 0652 0198 0027 0292 0861 1326 0499 0238 0606 0214 0405 0334 0310 0380 0233 2137 0091 0178 0602 0406 0043 0739 0085 3470 0586 0585 1409 1760 0410 1373 0294 0031 0313 0200 0430 0070 0297 0315 0333 0351 0464 0274 0620 0687 0276 0262 0872 0705 0472 0630'.split()
assert [x['id'] for x in items] == expected
assert Counter(x['category'] for x in items) == dict.fromkeys(['胸', '背', '肩膀', '腿', '二三頭', '核心'], 10)
assert len(source['revision']) == 40
originals = {x['id']: x for x in source['exercises']}
frame_count = 0
for x in items:
    assert len(x['steps']) >= 3 and all(step.strip() for step in x['steps'])
    original = originals[x['id']]
    assert original['instructions']['zh']
    assert x['gifFile'] == Path(original['gif_url']).name
    assert x['thumbnailFile'] == Path(original['image']).name
    assert x['attribution'] == original['attribution']
    assert 'Gym visual' in x['attribution'] and x['translationNote']
    for filename in [x['gifFile'], x['thumbnailFile']]:
        with Image.open(root / filename) as image:
            assert image.size == (180, 180), filename
            if filename.endswith('.gif'):
                assert image.n_frames > 1
                signatures = set()
                for index in range(image.n_frames):
                    image.seek(index)
                    signatures.add(image.convert('RGB').tobytes())
                    assert image.info['duration'] > 0
                assert len(signatures) > 1, filename
                frame_count += image.n_frames
    visible = ' '.join([x['name'], x['equipment'], x['muscles'], *x['steps']])
    assert not any(0x1F300 <= ord(c) <= 0x1FAFF for c in visible)
    assert not any(c in visible for c in '双脚哑铃杠盖弯绳缓练躯缩侧举转头撑稳组'), x['id']
assert len(list(root.glob('*.gif'))) == 60
assert len(list(root.glob('*.jpg'))) == 60
assert 'MIT License' in (root / 'DatasetLicense.txt').read_text()
assert 'Gym visual' in (root / 'MediaNotice.txt').read_text()
print(f'PASS: 60 exercises, 6 categories, 120 media files, {frame_count} GIF frames, provenance and notices.')

# Each category must resolve a different bundled cover; none may silently reuse the generic banner.
import hashlib
covers = [root / f'cover-{name}.png' for name in ['chest', 'back', 'shoulders', 'legs', 'arms', 'core']]
assert len({hashlib.sha256(p.read_bytes()).hexdigest() for p in covers}) == 6
for path in covers:
    with Image.open(path) as image:
        image.verify()
print('PASS: 6 distinct category covers.')
