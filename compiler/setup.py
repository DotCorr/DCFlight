"""Package the Dart API from its single source during Python wheel builds."""
from pathlib import Path
import shutil
from setuptools import setup
from setuptools.command.build_py import build_py


class BuildWithDartAuthoring(build_py):
    def run(self):
        super().run()
        source = Path(__file__).resolve().parent / 'authoring'
        destination = Path(self.build_lib) / 'dcflight/data/authoring'
        for relative in ('pubspec.yaml', 'lib/dcflight.dart'):
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / relative, target)

    def get_outputs(self, include_bytecode=1):
        files = super().get_outputs(include_bytecode)
        return files + [str(Path(self.build_lib) / 'dcflight/data/authoring' / relative)
                        for relative in ('pubspec.yaml', 'lib/dcflight.dart')]


setup(cmdclass={'build_py': BuildWithDartAuthoring})
