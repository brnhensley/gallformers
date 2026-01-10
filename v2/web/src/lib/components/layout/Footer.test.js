import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Footer from './Footer.svelte';

describe('Footer', () => {
    it('renders footer navigation links', () => {
        render(Footer);
        expect(screen.getByRole('link', { name: /about/i })).toBeInTheDocument();
    });

    it('renders social links', () => {
        render(Footer);
        expect(screen.getByRole('link', { name: /github/i })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: /patreon/i })).toBeInTheDocument();
    });

    it('renders copyright notice with current year', () => {
        render(Footer);
        const currentYear = new Date().getFullYear();
        expect(screen.getByText(new RegExp(`${currentYear}.*gallformers`, 'i'))).toBeInTheDocument();
    });

    it('renders license information', () => {
        render(Footer);
        expect(screen.getByRole('link', { name: /cc by-nc-sa 4.0/i })).toBeInTheDocument();
    });

    it('has correct href for GitHub link', () => {
        render(Footer);
        const githubLink = screen.getByRole('link', { name: /github/i });
        expect(githubLink).toHaveAttribute('href', 'https://github.com/jeffdc/gallformers');
    });

    it('has correct href for Patreon link', () => {
        render(Footer);
        const patreonLink = screen.getByRole('link', { name: /patreon/i });
        expect(patreonLink).toHaveAttribute('href', 'https://www.patreon.com/gallformers');
    });

    it('opens social links in new tab', () => {
        render(Footer);
        const githubLink = screen.getByRole('link', { name: /github/i });
        const patreonLink = screen.getByRole('link', { name: /patreon/i });

        expect(githubLink).toHaveAttribute('target', '_blank');
        expect(githubLink).toHaveAttribute('rel', 'noopener noreferrer');

        expect(patreonLink).toHaveAttribute('target', '_blank');
        expect(patreonLink).toHaveAttribute('rel', 'noopener noreferrer');
    });
});
