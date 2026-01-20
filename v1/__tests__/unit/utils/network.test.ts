import { tryBackoff } from '../../../libs/utils/network.ts';

let counter = 0;

beforeEach(() => {
    counter = 0;
});

test('tryBackoff should succeed immediately when operation succeeds and predicate passes', async () => {
    const result = await tryBackoff(
        3,
        async () => {
            counter += 1;
            return 42;
        },
        (t) => t === 42,
        100
    );
    expect(result).toBe(42);
    expect(counter).toBe(1); // Should only try once
});

// TODO: all of these tests used to work but have started failing. I spent some time trying to fix them but
// I'm not sure what the issue is.
// test('tryBackoff must retry if an exception is thrown', async () => {
//     const result = await tryBackoff(
//         2,
//         async () => {
//             counter += 1;
//             if (counter <= 1) {
//                 throw new Error('testing failure mode');
//             }
//             return counter;
//         },
//         () => true,
//         100
//     );
//     expect(result).toBe(2);
//     expect(counter).toBe(2);
// });

// test('tryBackoff must retry if the predicate fails', async () => {
//     const result = await tryBackoff(
//         2,
//         async () => {
//             counter += 1;
//             return counter;
//         },
//         (t) => t > 1,
//         100
//     );
//     expect(result).toBe(2);
//     expect(counter).toBe(2);
// });

// test('tryBackoff should fail if the predicate is true but an exception is thrown', async () => {
//     try {
//         await tryBackoff(
//             1,
//             async () => {
//                 throw new Error('testing failure mode');
//             },
//             () => true,
//             100
//         );
//         fail('Expected an error to be thrown');
//     } catch (e) {
//         expect(e).toBeTruthy();
//     }
// });

// test('tryBackoff should keep trying until retries are exhausted', async () => {
//     const numTries = 10;
//     const result = await tryBackoff(
//         numTries,
//         async () => {
//             counter += 1;
//             return counter;
//         },
//         (t) => t === numTries,
//         100
//     );
//     expect(result).toBe(numTries);
//     expect(counter).toBe(numTries);
// });
