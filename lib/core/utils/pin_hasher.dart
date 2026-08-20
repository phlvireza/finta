import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256, plus the constant-time comparison that must be used to
/// check its output.
///
/// **What this buys, honestly.** A six-digit PIN is one million candidates. No
/// key-derivation function makes that space large; PBKDF2 only makes each guess
/// cost more. At 100k iterations an attacker who has already extracted the
/// stored blob still gets through the whole space in hours on commodity
/// hardware. So this is not the control that protects the PIN — the platform
/// keystore that holds the blob is, and the attempt lockout in
/// `pin_attempt_policy.dart` is what stops guessing through the UI. PBKDF2 is
/// defence in depth for the case where the first two have already failed, and
/// user-facing copy must not claim more than that.
///
/// Written by hand because `crypto` ships HMAC but not PBKDF2, and because a
/// pure function here is directly unit-testable against published vectors —
/// the reason business logic in this project lives under `core/utils`.
///
/// [iterations] is stored alongside each hash rather than baked in as a
/// constant, so the cost can be raised later without stranding credentials
/// that were derived at the old cost.
Uint8List pbkdf2({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int keyLength = 32,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be at least 1');
  }
  if (keyLength < 1) {
    throw ArgumentError.value(keyLength, 'keyLength', 'must be at least 1');
  }

  final hmac = Hmac(sha256, password);
  const blockSize = 32; // SHA-256 output, in bytes.
  final blockCount = (keyLength + blockSize - 1) ~/ blockSize;
  final output = Uint8List(blockCount * blockSize);

  for (var block = 1; block <= blockCount; block++) {
    // U1 = PRF(password, salt || INT_32_BE(block)).
    final input = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = (block >> 24) & 0xff
      ..[salt.length + 1] = (block >> 16) & 0xff
      ..[salt.length + 2] = (block >> 8) & 0xff
      ..[salt.length + 3] = block & 0xff;

    var u = Uint8List.fromList(hmac.convert(input).bytes);
    final accumulator = Uint8List.fromList(u);

    // Un = PRF(password, Un-1), XOR-folded into the accumulator.
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < blockSize; j++) {
        accumulator[j] ^= u[j];
      }
    }

    output.setRange((block - 1) * blockSize, block * blockSize, accumulator);
  }

  return Uint8List.sublistView(output, 0, keyLength);
}

/// Compares two byte sequences without leaking where they first differ.
///
/// A plain `==` or `listEquals` returns as soon as it finds a mismatch, so the
/// time it takes reveals how many leading bytes were correct — enough, given
/// repeated attempts, to reconstruct a hash one byte at a time. This compares
/// every byte regardless.
///
/// The length check short-circuits on purpose: hash lengths here are fixed by
/// the algorithm, so a length mismatch is a malformed record rather than a
/// guess, and it leaks nothing about the contents.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
