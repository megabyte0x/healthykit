from __future__ import annotations

import secrets


def main() -> None:
    print(secrets.token_urlsafe(32))


if __name__ == "__main__":
    main()
