"""Register new Swift source files in the original hand-authored Xcode project.

XcodeGen project.yml is canonical; this keeps direct Xcode opening usable on
checkouts made before the generated project artifact is copied back from CI.
"""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
project = root / 'ChangXi.xcodeproj/project.pbxproj'
text = project.read_text(encoding='utf-8-sig')
build, refs, source_ids, file_ids = [], [], [], []
for file in sorted((root / 'ChangXi').rglob('*.swift')):
    if f'/* {file.name} */' in text:
        continue
    path = file.relative_to(root).as_posix()
    fid = hashlib.sha1(('file:' + path).encode()).hexdigest()[:24].upper()
    bid = hashlib.sha1(('build:' + path).encode()).hexdigest()[:24].upper()
    refs.append(f'\t\t{fid} /* {file.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT; }};')
    build.append(f'\t\t{bid} /* {file.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid}; }};')
    source_ids.append(f'\t\t\t\t{bid},')
    file_ids.append(f'\t\t\t\t{fid},')
text = text.replace('/* End PBXBuildFile section */', '\n'.join(build) + '\n/* End PBXBuildFile section */')
text = text.replace('/* End PBXFileReference section */', '\n'.join(refs) + '\n/* End PBXFileReference section */')
text = text.replace('A40000000000000000000002 /* ChangXi */,', 'A40000000000000000000002 /* ChangXi */,\n' + '\n'.join(file_ids))
text = text.replace('A10000000000000000000007,', 'A10000000000000000000007,\n' + '\n'.join(source_ids))
text = text.replace('INFOPLIST_KEY_NSMicrophoneUsageDescription =', 'INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "常曦将主动输入的语音转成文字。";\n\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription =')
project.write_text(text, encoding='utf-8')
