import {
    DetachableApi,
    DetachableBoth,
    DetachableDetachable,
    DetachableIntegral,
    DetachableNone,
    DetachableValues,
    GallIDApi,
    SearchQuery,
} from '../../../libs/api/apitypes';
import { checkGall, testables, LEAF_ANYWHERE, GALL_FORM, NONGALL_FORM } from '../../../libs/utils/gallsearch';

const { dontCare } = testables;

describe('dontCare tests', () => {
    test('Should return true for undefined, empty string, or empty array', () => {
        expect(dontCare(undefined)).toBeTruthy();
        expect(dontCare('')).toBeTruthy();
        expect(dontCare([])).toBeTruthy();
    });
});

describe('checkGall tests', () => {
    const g: GallIDApi = {
        id: -1,
        undescribed: false,
        alignments: [],
        cells: [],
        colors: [],
        detachable: DetachableNone,
        locations: [],
        seasons: [],
        textures: [],
        shapes: [],
        walls: [],
        forms: [],
        name: 'Gallus gallus',
        images: [],
        datacomplete: false,
        places: [],
        family: '',
    };

    const q: SearchQuery = {
        alignment: [],
        cells: [],
        color: [],
        detachable: [DetachableNone],
        locations: [],
        season: [],
        shape: [],
        textures: [],
        walls: [],
        form: [],
        undescribed: false,
        place: [],
        family: [],
    };

    // helper to create test galls in the tests.
    const makeG = (k: keyof GallIDApi, v: string[] | DetachableApi): GallIDApi => ({
        ...g,
        [k]: v,
    });

    test('Should not fail to match for any search field that is undefined, empty string, or empty array', () => {
        expect(checkGall(g, q)).toBeTruthy();
        
        expect(checkGall(makeG('alignments', ['vertical']), {
            ...q,
            alignment: ['vertical']
        })).toBeTruthy();
        
        expect(checkGall(makeG('cells', ['single']), {
            ...q,
            cells: ['single']
        })).toBeTruthy();
        
        expect(checkGall(makeG('colors', ['red']), {
            ...q,
            color: ['red']
        })).toBeTruthy();
        
        expect(checkGall(makeG('seasons', ['summer']), {
            ...q,
            season: ['summer']
        })).toBeTruthy();
        
        expect(checkGall(makeG('shapes', ['spherical']), {
            ...q,
            shape: ['spherical']
        })).toBeTruthy();
        
        expect(checkGall(makeG('walls', ['smooth']), {
            ...q,
            walls: ['smooth']
        })).toBeTruthy();
        
        expect(checkGall(makeG('locations', ['leaf']), {
            ...q,
            locations: ['leaf']
        })).toBeTruthy();
        
        expect(checkGall(makeG('textures', ['smooth']), {
            ...q,
            textures: ['smooth']
        })).toBeTruthy();
        
        expect(checkGall(makeG('places', ['north']), {
            ...q,
            place: ['north']
        })).toBeTruthy();
    });

    test('Should match when provided query has single matches', () => {
        expect(
            checkGall(makeG('alignments', ['foo']), {
                ...q,
                alignment: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('cells', ['foo']), {
                ...q,
                cells: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('colors', ['foo']), {
                ...q,
                color: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('seasons', ['foo']), {
                ...q,
                season: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('shapes', ['foo']), {
                ...q,
                shape: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('walls', ['foo']), {
                ...q,
                walls: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('locations', ['foo']), {
                ...q,
                locations: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('textures', ['foo']), {
                ...q,
                textures: ['foo'],
            }),
        ).toBeTruthy();
        expect(
            checkGall(makeG('places', ['foo']), {
                ...q,
                place: ['foo'],
            }),
        ).toBeTruthy();
    });

    test('Should handle all cases for detachable', () => {
        const conditions = [
            // 4 None cases all should match
            { a: DetachableDetachable, b: DetachableNone, expected: true },
            { a: DetachableIntegral, b: DetachableNone, expected: true },
            { a: DetachableBoth, b: DetachableNone, expected: true },
            { a: DetachableNone, b: DetachableNone, expected: true },
            // 3 Both cases one match two not
            { a: DetachableBoth, b: DetachableBoth, expected: true },
            { a: DetachableDetachable, b: DetachableBoth, expected: false },
            { a: DetachableIntegral, b: DetachableBoth, expected: false },
            // 3 Detachable cases two match one not
            { a: DetachableDetachable, b: DetachableDetachable, expected: true },
            { a: DetachableBoth, b: DetachableDetachable, expected: true },
            { a: DetachableIntegral, b: DetachableDetachable, expected: false },
            // 3 Integral cases two match one not
            { a: DetachableIntegral, b: DetachableIntegral, expected: true },
            { a: DetachableBoth, b: DetachableIntegral, expected: true },
            { a: DetachableDetachable, b: DetachableIntegral, expected: false },
        ];

        conditions.forEach(({ a, b, expected }) => {
            expect(
                checkGall(makeG('detachable', a), {
                    ...q,
                    detachable: [b],
                }),
            ).toBe(expected);
        });
    });

    test('Should match when provided query has multiple matches', () => {
        expect(
            checkGall(
                {
                    ...g,
                    alignments: ['afoo'],
                    colors: ['cofoo'],
                    cells: ['cefoo'],
                    seasons: ['sefoo'],
                    shapes: ['sfoo'],
                    walls: ['wfoo'],
                    locations: ['lfoo'],
                    textures: ['tfoo'],
                    places: ['pfoo'],
                },
                {
                    ...q,
                    alignment: ['afoo'],
                    color: ['cofoo'],
                    cells: ['cefoo'],
                    season: ['sefoo'],
                    shape: ['sfoo'],
                    walls: ['wfoo'],
                    locations: ['lfoo'],
                    textures: ['tfoo'],
                    place: ['pfoo'],
                },
            ),
        ).toBeTruthy();
    });

    test('Handles array types correctly', () => {
        const theG = {
            ...g,
            alignments: ['afoo1', 'afoo2'],
            colors: ['cfoo1', 'cfoo2'],
            seasons: ['sefoo1', 'sefoo2'],
            cells: ['cefoo1', 'cefoo2'],
            walls: ['wfoo1', 'wfoo2'],
            shapes: ['sfoo1', 'sfoo2'],
            locations: ['lfoo1', 'lfoo2'],
            textures: ['tfoo'],
        };

        expect(
            checkGall(theG, {
                ...q,
                locations: ['lfoo1'],
                textures: ['tfoo'],
            }),
        ).toBeTruthy();

        expect(
            checkGall(theG, {
                ...q,
                alignment: ['afoo1'],
                color: ['cfoo1'],
                season: ['sefoo1'],
                cells: ['cefoo1'],
                walls: ['wfoo1'],
                shape: ['sfoo1'],
                locations: ['lfoo1'],
                textures: ['tfoo'],
            }),
        ).toBeTruthy();

        expect(
            checkGall(theG, {
                ...q,
                walls: ['wfoo1', 'wfoo2'],
                locations: ['lfoo1', 'lfoo2'],
                textures: ['tfoo'],
            }),
        ).toBeTruthy();

        expect(
            checkGall(theG, {
                ...q,
                locations: ['lfoo1', 'lfoo2', 'nope'],
                textures: ['tfoo'],
            }),
        ).toBeFalsy();

        expect(
            checkGall(theG, {
                ...q,
                alignment: [],
                color: [],
                cells: [],
                season: [],
                walls: [],
                shape: [],
                locations: [],
                textures: [],
            }),
        ).toBeTruthy();
    });
});

describe('gallsearch', () => {
    describe('dontCare', () => {
        it('should return true for undefined', () => {
            expect(testables.dontCare(undefined)).toBe(true);
        });

        it('should return true for empty string', () => {
            expect(testables.dontCare('')).toBe(true);
        });

        it('should return true for empty array', () => {
            expect(testables.dontCare([])).toBe(true);
        });

        it('should return false for non-empty string', () => {
            expect(testables.dontCare('test')).toBe(false);
        });

        it('should return false for non-empty array', () => {
            expect(testables.dontCare(['test'])).toBe(false);
        });
    });

    describe('checkDetachable', () => {
        // We need to access the private checkDetachable function
        // Since it's not exported, we'll test it indirectly through checkGall
        const createGallWithDetachable = (detachable: DetachableApi): GallIDApi => ({
            detachable,
            alignments: [],
            cells: [],
            colors: [],
            seasons: [],
            shapes: [],
            walls: [],
            locations: [],
            textures: [],
            forms: [],
            places: [],
            family: '',
            undescribed: false,
            id: 1,
            name: 'Test Gall',
            datacomplete: false,
            images: []
        });

        const createSearchQueryWithDetachable = (detachable: DetachableApi): SearchQuery => ({
            detachable: [detachable],
            alignment: [],
            cells: [],
            color: [],
            season: [],
            shape: [],
            walls: [],
            locations: [],
            textures: [],
            form: [],
            place: [],
            family: [],
            undescribed: false
        });

        it('should match when query is DetachableNone', () => {
            const gall = createGallWithDetachable({ id: 1, value: DetachableValues.INTEGRAL });
            const query = createSearchQueryWithDetachable(DetachableNone);
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should match when both are DetachableBoth', () => {
            const gall = createGallWithDetachable(DetachableBoth);
            const query = createSearchQueryWithDetachable(DetachableBoth);
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should match when values are equal', () => {
            const gall = createGallWithDetachable({ id: 1, value: DetachableValues.INTEGRAL });
            const query = createSearchQueryWithDetachable({ id: 1, value: DetachableValues.INTEGRAL });
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should match when gall is DetachableBoth', () => {
            const gall = createGallWithDetachable(DetachableBoth);
            const query = createSearchQueryWithDetachable({ id: 1, value: DetachableValues.INTEGRAL });
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should not match when values are different', () => {
            const gall = createGallWithDetachable({ id: 1, value: DetachableValues.INTEGRAL });
            const query = createSearchQueryWithDetachable({ id: 1, value: DetachableValues.DETACHABLE });
            expect(checkGall(gall, query)).toBe(false);
        });
    });

    describe('checkGall', () => {
        const createBaseGall = (): GallIDApi => ({
            detachable: { id: 1, value: DetachableValues.INTEGRAL },
            alignments: ['vertical'],
            cells: ['single'],
            colors: ['red'],
            seasons: ['summer'],
            shapes: ['spherical'],
            walls: ['smooth'],
            locations: ['leaf'],
            textures: ['smooth'],
            forms: ['leaf'],
            places: ['north'],
            family: 'Cynipidae',
            undescribed: false,
            id: 1,
            name: 'Test Gall',
            datacomplete: false,
            images: []
        });

        const createBaseQuery = (): SearchQuery => ({
            detachable: [{ id: 1, value: DetachableValues.INTEGRAL }],
            alignment: [],
            cells: [],
            color: [],
            season: [],
            shape: [],
            walls: [],
            locations: [],
            textures: [],
            form: [],
            place: [],
            family: [],
            undescribed: false
        });

        it('should match when all criteria are empty (dontCare)', () => {
            const gall = createBaseGall();
            const query = createBaseQuery();
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should match when all criteria match', () => {
            const gall = createBaseGall();
            const query = {
                ...createBaseQuery(),
                alignment: ['vertical'],
                cells: ['single'],
                color: ['red'],
                season: ['summer'],
                shape: ['spherical'],
                walls: ['smooth'],
                locations: ['leaf'],
                textures: ['smooth'],
                form: ['leaf'],
                place: ['north'],
                family: ['Cynipidae']
            };
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should not match when any criterion does not match', () => {
            const gall = createBaseGall();
            const query = {
                ...createBaseQuery(),
                alignment: ['horizontal'] // Different from gall's 'vertical'
            };
            expect(checkGall(gall, query)).toBe(false);
        });

        it('should handle LEAF_ANYWHERE location', () => {
            const gall = createBaseGall();
            const query = {
                ...createBaseQuery(),
                locations: [LEAF_ANYWHERE]
            };
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should handle LEAF_ANYWHERE with additional locations', () => {
            const gall = createBaseGall();
            const query = {
                ...createBaseQuery(),
                locations: [LEAF_ANYWHERE, 'stem']
            };
            expect(checkGall(gall, query)).toBe(false);
        });

        it('should handle GALL_FORM correctly', () => {
            const gall = createBaseGall();
            const query = {
                ...createBaseQuery(),
                form: [GALL_FORM]
            };
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should handle NONGALL_FORM correctly', () => {
            const gall = {
                ...createBaseGall(),
                forms: [NONGALL_FORM]
            };
            const query = {
                ...createBaseQuery(),
                form: [GALL_FORM]
            };
            expect(checkGall(gall, query)).toBe(false);
        });

        it('should handle undescribed correctly', () => {
            const gall = {
                ...createBaseGall(),
                undescribed: true
            };
            const query = {
                ...createBaseQuery(),
                undescribed: true
            };
            expect(checkGall(gall, query)).toBe(true);
        });

        it('should not match when gall is not undescribed but query requires it', () => {
            const gall = createBaseGall(); // undescribed: false
            const query = {
                ...createBaseQuery(),
                undescribed: true
            };
            expect(checkGall(gall, query)).toBe(false);
        });
    });
});
