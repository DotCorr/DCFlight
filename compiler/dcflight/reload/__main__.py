import argparse
import sys
from .watch import run


def main():
    p=argparse.ArgumentParser(description='Development-only native watch/rebuild. Mobile code swapping is not yet integrated.')
    p.add_argument('source');p.add_argument('--out',required=True);p.add_argument('--target',choices=('ios','android'),required=True)
    p.add_argument('--device');p.add_argument('--build-only',action='store_true');p.add_argument('--once',action='store_true')
    p.add_argument('--evaluate-dart',action='store_true');p.add_argument('--dart-sdk',default='dart')
    p.add_argument('--android-sdk');p.add_argument('--java-home');p.add_argument('--gradle')
    p.add_argument('--watch',action='append',default=[],help='Additional source directories, including external Dart imports')
    p.add_argument('--interval',type=float,default=0.5)
    try:return run(p.parse_args())
    except KeyboardInterrupt:return 130
    except (ValueError,OSError) as error:print(str(error),file=sys.stderr);return 1

if __name__=='__main__':sys.exit(main())
