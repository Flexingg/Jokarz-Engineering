/// Exceptions for the BAMM write path.
///
/// [BammFieldValidationException] marks a problem with the *caller's input*
/// (a bad value, an empty required field). It must always be thrown before
/// any network call is attempted, and must never be confused with
/// [BammModelException] or a transport failure - "BAMM is broken" and "you
/// typed a word in a number field" must never look the same to a caller.
library;

/// A problem in the shape of a BAMM model itself (missing property, missing
/// child set, mismatched id) - discovered only after talking to BAMM, as
/// opposed to a caller-input problem ([BammFieldValidationException]).
class BammModelException implements Exception {
  final String message;
  const BammModelException(this.message);

  @override
  String toString() => message;
}

/// Bad caller input: an unparseable value, a missing required field. Raised
/// before any HTTP call - see the module doc comment.
class BammFieldValidationException implements Exception {
  final String message;
  const BammFieldValidationException(this.message);

  @override
  String toString() => message;
}
