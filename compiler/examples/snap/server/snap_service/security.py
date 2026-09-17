import hashlib
import hmac
import secrets


def password_hash(password, salt=None):
    salt = salt or secrets.token_bytes(16)
    derived = hashlib.scrypt(password.encode('utf-8'), salt=salt, n=32768, r=8, p=1, maxmem=64*1024*1024, dklen=64)
    return 'scrypt$32768$8$1$' + salt.hex() + '$' + derived.hex()


def password_matches(password, encoded):
    if not encoded:
        # Match the work factor for nonexistent users without authenticating them.
        password_hash(password, b'\0' * 16)
        return False
    try:
        algorithm, n, r, p, salt, expected = encoded.split('$')
        if (algorithm,n,r,p) != ('scrypt','32768','8','1'):
            return False
        actual = password_hash(password, bytes.fromhex(salt)).split('$')[-1]
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()
