"""Console entry point for the dcflight MCP stdio server (`dcflight-mcp`)."""
import sys


def main(argv=None):
    from .mcp import serve
    serve()
    return 0


if __name__ == '__main__':
    sys.exit(main())
