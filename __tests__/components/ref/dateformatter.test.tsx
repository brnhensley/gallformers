import { render, screen } from '@testing-library/react';
import DateFormatter from '../../../components/ref/dateformatter';
import { es } from 'date-fns/locale';

describe('DateFormatter', () => {
    it('renders formatted date correctly', () => {
        const dateString = '2024-04-13';
        render(<DateFormatter dateString={dateString} />);

        // The exact format will be "April 13, 2024"
        expect(screen.getByText(/April 13, 2024/)).toBeInTheDocument();
    });

    it('sets correct datetime attribute', () => {
        const dateString = '2024-04-13';
        render(<DateFormatter dateString={dateString} />);

        const timeElement = screen.getByText(/April 13, 2024/);
        expect(timeElement).toHaveAttribute('datetime', dateString);
    });

    it('handles different date formats', () => {
        const testCases = [
            { input: '2024-01-01', expected: 'January 1, 2024' },
            { input: '2024-12-31', expected: 'December 31, 2024' },
            { input: '2024-06-15', expected: 'June 15, 2024' },
        ];

        testCases.forEach(({ input, expected }) => {
            const { unmount } = render(<DateFormatter dateString={input} />);
            expect(screen.getByText(expected)).toBeInTheDocument();
            unmount();
        });
    });

    it('handles leap year dates', () => {
        const dateString = '2024-02-29';
        render(<DateFormatter dateString={dateString} />);
        expect(screen.getByText(/February 29, 2024/)).toBeInTheDocument();
    });

    it('handles invalid date strings', () => {
        const invalidDate = 'invalid-date';
        render(<DateFormatter dateString={invalidDate} />);
        expect(screen.getByText('Invalid date')).toBeInTheDocument();
    });

    it('uses custom fallback text for invalid dates', () => {
        const invalidDate = 'invalid-date';
        const fallback = 'Fecha inválida';
        render(<DateFormatter dateString={invalidDate} fallback={fallback} />);
        expect(screen.getByText(fallback)).toBeInTheDocument();
    });

    it('supports different locales', () => {
        const dateString = '2024-04-13';
        render(<DateFormatter dateString={dateString} locale={es} />);
        expect(screen.getByText(/abril 13, 2024/i)).toBeInTheDocument();
    });

    it('memoizes formatted date', () => {
        const dateString = '2024-04-13';
        const { rerender } = render(<DateFormatter dateString={dateString} />);

        // First render
        const initialElement = screen.getByText(/April 13, 2024/);

        // Rerender with same props
        rerender(<DateFormatter dateString={dateString} />);

        // Should be the same element instance due to memoization
        expect(screen.getByText(/April 13, 2024/)).toBe(initialElement);
    });
});
