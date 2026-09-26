/**
 * Shared "never send" key denylist for Sentry event scrubbing — mirrors
 * lib/core/monitoring/pii_scrub.dart on the Flutter side (can't literally
 * share code across Dart/TS, so the denylist and matching logic are kept
 * in sync by hand; keep both lists identical when editing either).
 *
 * Matching is case-insensitive and ignores underscores/hyphens, so
 * `childName`, `child_name`, and `CHILD-NAME` are all caught by one entry.
 */
export const deniedPropertyKeyFragments = [
  'childname',
  'child',
  'dob',
  'dateofbirth',
  'birthdate',
  'assessmentanswer',
  'answertext',
  'questiontext',
  'diagnosis',
  'email',
  'authtoken',
  'accesstoken',
  'refreshtoken',
  'authorization',
  'token',
  'prompt',
  'databasepayload',
  'dbpayload',
  'rawpayload',
  'password',
];

function normalizeKey(key: string): string {
  return key.toLowerCase().replace(/[_\-\s]/g, '');
}

export function isDeniedPropertyKey(key: string): boolean {
  const normalized = normalizeKey(key);
  return deniedPropertyKeyFragments.some((fragment) => normalized.includes(fragment));
}

/**
 * Removes every denylisted key from `properties`, recursively into any
 * nested plain-object values. Never mutates the input — returns a new
 * object. Arrays and non-plain-object values are passed through as-is
 * (recursion only descends into plain objects, matching the Dart side's
 * `Map<String, Object?>`-only recursion).
 */
export function scrubDeniedKeys(properties: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(properties)) {
    if (isDeniedPropertyKey(key)) continue;
    result[key] =
      value !== null && typeof value === 'object' && !Array.isArray(value)
        ? scrubDeniedKeys(value as Record<string, unknown>)
        : value;
  }
  return result;
}
