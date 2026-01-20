import * as fc from 'fast-check';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { genOptions, genOptionsWithId } from '../../../libs/utils/forms';

describe('The Forms Util genOptions()', () => {
    it('should render valid options with an empty array as input', () => {
        expect(genOptions([])).toBeTruthy();
    });

    it('should throw when given an options input that contains duplicates', () => {
        // must be in function for the throw check to work
        expect(() => {
            genOptions(['a', 'a']);
        }).toThrow();
    });

    it('should render valid options given valid options input', () => {
        fc.assert(
            fc.property(fc.uniqueArray(fc.unicodeString({ minLength: 1 })), (values) => {
                render(genOptions(values));
                values.forEach((v) => {
                    screen.queryAllByText(v).forEach((d) => expect(d).toBeInTheDocument());
                });
            }),
        );
    });

    it('should not include an empty option when told not to', () => {
        const opts = render(genOptions(['a'], false));
        // expect it to be 2, since the body and the div will show as empty text.
        expect(screen.queryAllByText('').length).toBe(2);
        opts.unmount();

        // now it should be 4 to account for the empty option: body, empty div (fragment), div, option
        render(genOptions(['a'], true));
        expect(screen.queryAllByText('').length).toBe(4);
    });
});

describe('The Forms Util genOptionsWithId()', () => {
    it('should render valid options with an empty array as input', () => {
        expect(genOptionsWithId([])).toBeTruthy();
    });

    it('should throw when given an options input that contains duplicates', () => {
        // must be in function for the throw check to work
        expect(() => {
            // Using the same object reference to trigger the duplicate check
            const duplicateOption = { id: 1, name: 'a' };
            genOptionsWithId([duplicateOption, duplicateOption]);
        }).toThrow();
    });

    it('should render valid options given valid options input', () => {
        const testOptions = [
            { id: 1, name: 'Option 1' },
            { id: 2, name: 'Option 2' },
            { id: 3, name: 'Option 3' },
        ];
        
        render(genOptionsWithId(testOptions));
        
        testOptions.forEach((option) => {
            const optionElements = screen.queryAllByText(option.name);
            expect(optionElements.length).toBeGreaterThan(0);
            optionElements.forEach((element) => {
                expect(element).toBeInTheDocument();
                expect(element).toHaveAttribute('value', option.name);
                expect(element).toHaveAttribute('id', option.id.toString());
            });
        });
    });

    it('should not include an empty option when told not to', () => {
        const testOptions = [{ id: 1, name: 'Option 1' }];
        
        const opts = render(genOptionsWithId(testOptions, false));
        // expect it to be 2, since the body and the div will show as empty text.
        expect(screen.queryAllByText('').length).toBe(2);
        opts.unmount();

        // now it should be 4 to account for the empty option: body, empty div (fragment), div, option
        render(genOptionsWithId(testOptions, true));
        expect(screen.queryAllByText('').length).toBe(4);
    });

    it('should handle options with string IDs', () => {
        const testOptions = [
            { id: 'id1', name: 'Option 1' },
            { id: 'id2', name: 'Option 2' },
        ];
        
        render(genOptionsWithId(testOptions));
        
        testOptions.forEach((option) => {
            const optionElements = screen.queryAllByText(option.name);
            expect(optionElements.length).toBeGreaterThan(0);
            optionElements.forEach((element) => {
                expect(element).toBeInTheDocument();
                expect(element).toHaveAttribute('value', option.name);
                expect(element).toHaveAttribute('id', option.id.toString());
            });
        });
    });
});
