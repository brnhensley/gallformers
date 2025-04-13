import * as fc from 'fast-check';
import { constant, pipe } from 'fp-ts/lib/function';
import * as TE from 'fp-ts/lib/TaskEither';
import * as O from 'fp-ts/lib/Option';
import * as U from '../../../libs/utils/util';

test('randInt should always return a number within the bounds', () => {
    fc.assert(
        fc.property(
            fc.tuple(fc.integer(), fc.integer()).filter((t) => t[0] < t[1]),
            (t) => {
                const [lower, upper] = t;
                const x = U.randInt(lower, upper);
                expect(x).toBeLessThanOrEqual(upper);
                expect(x).toBeGreaterThanOrEqual(lower);
            },
        ),
    );
});

test('randInt should fail with invalid inputs', () => {
    fc.assert(
        fc.property(
            fc.tuple(fc.integer(), fc.integer()).filter((t) => t[0] >= t[1]),
            (t) => {
                const [lower, upper] = t;
                expect(() => U.randInt(lower, upper)).toThrow();
            },
        ),
    );
});

test('hasProp should detect props', () => {
    fc.assert(
        fc.property(fc.object(), (o) => {
            for (const p in o) {
                expect(U.hasProp(o, p)).toBeTruthy();
            }
            fc.property(
                fc.string().filter((s) => !U.hasProp(o, s)),
                (p) => {
                    expect(U.hasProp(o, p)).toBeFalsy();
                },
            );
        }),
    );
});

test('hasProp should handle null and undefined', () => {
    expect(U.hasProp(null, 'test')).toBeFalsy();
    expect(U.hasProp(undefined, 'test')).toBeFalsy();
});

const anError = new Error('this is an expected test exception, it does not mean anything went awry!');

test('mightFail should return the passed in default on failure', async () => {
    const r = await pipe(
        TE.left<Error, unknown[]>(anError),
        U.mightFail(constant(new Array<unknown>())),
    );

    expect(r.length).toBe(0);
});

test('mightFailWithOptional should return None on failure', async () => {
    const r = await pipe(
        TE.left<Error, O.Option<string>>(anError),
        U.mightFailWithOptional<string>(),
    );

    expect(O.isNone(r)).toBeTruthy();
});

test('mightFailWithArray should return empty array on failure', async () => {
    const r = await pipe(
        TE.left<Error, string[]>(anError),
        U.mightFailWithStringArray,
    );

    expect(r).toEqual([]);
});

test('mightFailWithMap should return empty map on failure', async () => {
    const r = await pipe(
        TE.left<Error, Map<string, number>>(anError),
        U.mightFailWithMap<string, number>(),
    );

    expect(r.size).toBe(0);
});

test('errorThrow should always throw', () => {
    expect(() => U.errorThrow(anError)).toThrow();
});

test('handleError should convert to an Error', () => {
    expect(U.handleError('foo').message).toBe('foo');
    expect(U.handleError(anError)).toBe(anError);
    expect(U.handleError(123).message).toBe('123');
    expect(U.handleError(null).message).toBe('null');
});

test('truncateAtWord should handle varying input', () => {
    // Test with specific cases first
    expect(U.truncateAtWord(2)('')).toBe('');
    expect(U.truncateAtWord(2)('   ')).toBe('   ');
    expect(U.truncateAtWord(2)('one two three')).toBe('one two...');
    
    // Then test with property-based testing for non-empty strings
    fc.assert(
        fc.property(
            fc.array(fc.unicodeString({ minLength: 1 }), { minLength: 3, maxLength: 10 }),
            (values) => {
                const s = values.join(' ');
                const t = U.truncateAtWord(2)(s);
                if (s.split(' ').length <= 2) {
                    expect(t).toBe(s);
                } else {
                    expect(t.endsWith('...')).toBeTruthy();
                    expect(t.split(' ').length).toBeLessThanOrEqual(3); // 2 words + potential partial word
                }
            },
        ),
    );
});

describe('String manipulation functions', () => {
    test('capitalizeFirstLetter should handle various inputs', () => {
        expect(U.capitalizeFirstLetter('')).toBe('');
        expect(U.capitalizeFirstLetter('a')).toBe('A');
        expect(U.capitalizeFirstLetter('test')).toBe('Test');
        expect(U.capitalizeFirstLetter('TEST')).toBe('TEST');
    });

    test('lowercaseFirstLetter should handle various inputs', () => {
        expect(U.lowercaseFirstLetter('')).toBe('');
        expect(U.lowercaseFirstLetter('A')).toBe('a');
        expect(U.lowercaseFirstLetter('Test')).toBe('test');
        expect(U.lowercaseFirstLetter('test')).toBe('test');
    });
});

test('csvAsNumberArr should handle all inputs good and bad', () => {
    expect(U.csvAsNumberArr('').length).toBe(0);
    expect(U.csvAsNumberArr(' ').length).toBe(0);
    expect(U.csvAsNumberArr(' , ').length).toBe(0);
    expect(U.csvAsNumberArr('1, ').length).toBe(0);
    expect(U.csvAsNumberArr('1,a').length).toBe(0); // Invalid number
    expect(U.csvAsNumberArr('1,NaN').length).toBe(0); // NaN case

    expect(U.csvAsNumberArr('1').length).toBe(1);
    expect(U.csvAsNumberArr('1,2').length).toBe(2);
    expect(U.csvAsNumberArr('1 , 2').length).toBe(2);
    expect(U.csvAsNumberArr('\t       1 , \n2').length).toBe(2);
});

describe('extractGenus tests', () => {
    test('it must act as the identity if passed in a string whose format is not conformant', () => {
        fc.assert(
            fc.property(
                fc.string().filter((s) => !s.includes(' ')),
                (s) => expect(U.extractGenus(s)).toBe(s),
            ),
        );
    });

    test('it must extract the genus when passed a conformant string', () => {
        expect(U.extractGenus('Foo bar')).toBe('Foo');
        expect(U.extractGenus('Foo bar baz')).toBe('Foo');
        expect(U.extractGenus('Foo')).toBe('Foo');
    });
});

describe('pluralize tests', () => {
    test('it must change y to ies', () => {
        expect(U.pluralize('Family')).toBe('Families');
        expect(U.pluralize('fly')).toBe('flies');
    });

    test('it must handle words ending in s', () => {
        expect(U.pluralize('class')).toBe('class'); // Returns unchanged if ends in 's'
        expect(U.pluralize('Terms')).toBe('Terms');
        expect(U.pluralize('pass')).toBe('pass');
    });

    test('it must add s to other words', () => {
        expect(U.pluralize('Gall')).toBe('Galls');
        expect(U.pluralize('tree')).toBe('trees');
        expect(U.pluralize('book')).toBe('books');
    });
});

describe('Option utilities', () => {
    test('optionalWith should handle null and non-null values', () => {
        expect(O.isNone(U.optionalWith(null, (x) => x))).toBeTruthy();
        expect(O.isSome(U.optionalWith(1, (x) => x))).toBeTruthy();
        expect(U.optionalWith(1, (x) => x * 2)).toEqual(O.some(2));
    });

    test('check should compare Options correctly', () => {
        expect(U.check(O.none, O.none, (a, b) => a === b)).toBeTruthy();
        expect(U.check(O.some(1), O.none, (a, b) => a === b)).toBeFalsy();
        expect(U.check(O.none, O.some(1), (a, b) => a === b)).toBeTruthy();
        expect(U.check(O.some(1), O.some(1), (a, b) => a === b)).toBeTruthy();
        expect(U.check(O.some(1), O.some(2), (a, b) => a === b)).toBeFalsy();
    });

    test('serializeOption and deserializeOption should be inverses', () => {
        const testCases: O.Option<string>[] = [O.none, O.some("test1"), O.some("test2")];
        testCases.forEach(testCase => {
            const serialized = U.serializeOption(testCase);
            const deserialized = U.deserializeOption<string>(serialized);
            expect(deserialized).toEqual(testCase);
        });
    });
});

describe('sessionUserOrUnknown tests', () => {
    test('should handle all input cases', () => {
        expect(U.sessionUserOrUnknown(null)).toBe('UNKNOWN!');
        expect(U.sessionUserOrUnknown(undefined)).toBe('UNKNOWN!');
        expect(U.sessionUserOrUnknown('user')).toBe('user');
        // Empty string is considered falsy in JavaScript, so it should return UNKNOWN!
        expect(U.sessionUserOrUnknown('')).toBe('UNKNOWN!');
    });
});

describe('isValidSpeciesName tests', () => {
    const validNames = [
        'Foo bar',
        'Foo bar-baz',
        'Foo bar-baz-boo',
        'Foo bar-baz (boo)',
        'Foo bar-baz (boo) (boo)',
        'Foo x bar',
        'Foo X bar',
        'Foo x bar-baz',
        'Foo x bar-baz (boo)',
        'Foo x bar-baz (boo) (boo)',
    ];

    const invalidNames = [
        'foo bar', // First word must be capitalized
        'F bar', // First word must have at least 2 letters
        ' Foo bar', // No leading space
        'foo', // Must have two words
        'Foo', // Must have two words
        'Foo Bar', // Second word must be lowercase
        'Foo bar baz', // No spaces after second word (must use hyphens)
        'Foo bar.baz', // Only hyphens allowed between words
        'Foo bar ()', // Empty parentheses not allowed
        'Foo bar (baz', // Unclosed parentheses not allowed
        'Foo bar baz)', // Unopened parentheses not allowed
    ];

    test.each(validNames)('should accept valid species name: "%s"', (name) => {
        const result = U.isValidSpeciesName(name);
        expect(result).toBeTruthy();
    });

    test.each(invalidNames)('should reject invalid species name: "%s"', (name) => {
        const result = U.isValidSpeciesName(name);
        expect(result).toBeFalsy();
    });
});
