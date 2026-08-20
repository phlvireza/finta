import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/pin_hasher.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('pbkdf2', () {
    // Published PBKDF2-HMAC-SHA256 vectors — the SHA-256 counterparts to the
    // SHA-1 vectors in RFC 6070, and the same values OpenSSL and Python's
    // hashlib produce. A hand-written KDF is only trustworthy against known
    // answers, so these come first.
    test('matches the published vector at 1 iteration', () {
      expect(
        _hex(pbkdf2(
          password: utf8.encode('password'),
          salt: utf8.encode('salt'),
          iterations: 1,
        )),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the published vector at 2 iterations', () {
      // Proves the XOR-fold across iterations, which a 1-iteration test
      // cannot reach at all.
      expect(
        _hex(pbkdf2(
          password: utf8.encode('password'),
          salt: utf8.encode('salt'),
          iterations: 2,
        )),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('matches the published vector at 4096 iterations', () {
      expect(
        _hex(pbkdf2(
          password: utf8.encode('password'),
          salt: utf8.encode('salt'),
          iterations: 4096,
        )),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('matches the published 40-byte vector spanning two blocks', () {
      // 40 bytes needs two SHA-256 blocks, so this is the only vector that
      // exercises the block counter and the final truncation.
      expect(
        _hex(pbkdf2(
          password: utf8.encode('passwordPASSWORDpassword'),
          salt: utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
          iterations: 4096,
          keyLength: 40,
        )),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
        'c635518c7dac47e9',
      );
    });

    test('returns exactly the requested key length', () {
      for (final length in [1, 16, 31, 32, 33, 64]) {
        expect(
          pbkdf2(
            password: utf8.encode('1234'),
            salt: utf8.encode('s'),
            iterations: 2,
            keyLength: length,
          ).length,
          length,
        );
      }
    });

    test('is deterministic for the same PIN and salt', () {
      final a = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('abc'), iterations: 64);
      final b = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('abc'), iterations: 64);
      expect(a, b);
    });

    test('a different salt gives a different hash for the same PIN', () {
      // The reason each credential carries its own random salt: two users who
      // pick 123456 must not end up with the same stored bytes.
      final a = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('salt-a'), iterations: 64);
      final b = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('salt-b'), iterations: 64);
      expect(a, isNot(b));
    });

    test('a different PIN gives a different hash for the same salt', () {
      final a = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('abc'), iterations: 64);
      final b = pbkdf2(password: utf8.encode('123457'), salt: utf8.encode('abc'), iterations: 64);
      expect(a, isNot(b));
    });

    test('a different iteration count gives a different hash', () {
      // Which is why the count is stored with the credential — raising it
      // later must not silently invalidate existing PINs by accident.
      final a = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('abc'), iterations: 64);
      final b = pbkdf2(password: utf8.encode('123456'), salt: utf8.encode('abc'), iterations: 128);
      expect(a, isNot(b));
    });

    test('rejects a non-positive iteration count instead of returning weak output', () {
      expect(
        () => pbkdf2(password: utf8.encode('1'), salt: utf8.encode('s'), iterations: 0),
        throwsArgumentError,
      );
      expect(
        () => pbkdf2(password: utf8.encode('1'), salt: utf8.encode('s'), iterations: -1),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive key length', () {
      expect(
        () => pbkdf2(
          password: utf8.encode('1'),
          salt: utf8.encode('s'),
          iterations: 1,
          keyLength: 0,
        ),
        throwsArgumentError,
      );
    });

    test('accepts an empty salt without crashing', () {
      // Never produced by the app, but a corrupted stored record could hand
      // one back, and throwing here would lock the user out permanently.
      expect(
        pbkdf2(password: utf8.encode('123456'), salt: const [], iterations: 2).length,
        32,
      );
    });
  });

  group('constantTimeEquals', () {
    test('equal sequences compare equal', () {
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2, 3]), isTrue);
      expect(constantTimeEquals(const [], const []), isTrue);
    });

    test('a difference anywhere compares unequal', () {
      // First byte, last byte, and the middle — the point of the function is
      // that position does not change the answer or the timing.
      expect(constantTimeEquals(const [9, 2, 3], const [1, 2, 3]), isFalse);
      expect(constantTimeEquals(const [1, 9, 3], const [1, 2, 3]), isFalse);
      expect(constantTimeEquals(const [1, 2, 9], const [1, 2, 3]), isFalse);
    });

    test('different lengths compare unequal', () {
      expect(constantTimeEquals(const [1, 2], const [1, 2, 3]), isFalse);
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2]), isFalse);
      expect(constantTimeEquals(const [], const [0]), isFalse);
    });

    test('works across list types, so a stored hash compares to a fresh one', () {
      final derived = pbkdf2(
        password: utf8.encode('123456'),
        salt: utf8.encode('abc'),
        iterations: 8,
      );
      final roundTripped = Uint8List.fromList(base64Decode(base64Encode(derived)));
      expect(constantTimeEquals(derived, roundTripped), isTrue);
    });
  });
}
