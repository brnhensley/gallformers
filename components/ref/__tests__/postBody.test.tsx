import React from 'react';
import { render, screen } from '@testing-library/react';
import PostBody from '../postBody';
import DOMPurify from 'dompurify';

// Mock DOMPurify
jest.mock('dompurify', () => ({
    __esModule: true,
    default: {
        sanitize: jest.fn((content: string) => content),
    },
}));

describe('PostBody', () => {
    it('renders content correctly', () => {
        const content = '<p>Test content</p>';
        render(<PostBody content={content} />);

        expect(screen.getByRole('article')).toBeInTheDocument();
        expect(screen.getByRole('article')).toHaveTextContent('Test content');
    });

    it('applies custom className when provided', () => {
        const content = '<p>Test content</p>';
        const customClass = 'custom-class';

        render(<PostBody content={content} className={customClass} />);

        const element = screen.getByRole('article');
        expect(element).toHaveClass('custom-class');
        expect(element).toHaveClass('markdown');
    });

    it('sanitizes content using DOMPurify', () => {
        const content = '<script>alert("xss")</script><p>Safe content</p>';

        render(<PostBody content={content} />);

        // Use a spy to check if sanitize was called
        const sanitizeSpy = jest.spyOn(DOMPurify, 'sanitize');
        expect(sanitizeSpy).toHaveBeenCalledWith(content);
        expect(screen.getByRole('article')).toHaveTextContent('Safe content');
    });
});
