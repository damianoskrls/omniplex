// Phone columns are utf8mb4_unicode_ci. The pool sets the session to
// utf8mb4_0900_ai_ci, so bare literals inside REPLACE/COALESCE ('', ' ', '+')
// raise "Illegal mix of collations ... for operation '='". Force one collation
// on the column and on every literal. `column` must be a trusted identifier.

const PHONE_COLLATE = 'utf8mb4_unicode_ci';

function assertPhoneColumn(column) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?$/.test(column)) {
    throw new Error(`Invalid phone column: ${column}`);
  }
}

function utf8mb4Literal(value) {
  return `_utf8mb4'${value}' COLLATE ${PHONE_COLLATE}`;
}

function phoneDigitsExpr(column) {
  assertPhoneColumn(column);
  const empty = utf8mb4Literal('');
  const col = `${column} COLLATE ${PHONE_COLLATE}`;
  return `REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(${col}, ${empty}), ${utf8mb4Literal(' ')}, ${empty}), ${utf8mb4Literal('+')}, ${empty}), ${utf8mb4Literal('-')}, ${empty}), ${utf8mb4Literal('(')}, ${empty}), ${utf8mb4Literal(')')}, ${empty}), ${utf8mb4Literal('.')}, ${empty})`;
}

function phoneDigitsLike(column) {
  return `${phoneDigitsExpr(column)} LIKE CONVERT(? USING utf8mb4) COLLATE ${PHONE_COLLATE}`;
}

function phoneDigitsEq(column) {
  return `${phoneDigitsExpr(column)} = CONVERT(? USING utf8mb4) COLLATE ${PHONE_COLLATE}`;
}

module.exports = { phoneDigitsExpr, phoneDigitsLike, phoneDigitsEq };
