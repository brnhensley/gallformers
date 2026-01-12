import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Footer from './Footer.svelte';

describe('Footer', () => {
    it('renders footer navigation links', () => {
        render(Footer);
        // Footer has both desktop and mobile nav, so multiple About links exist
        const aboutLinks = screen.getAllByRole('link', { name: /about/i });
        expect(aboutLinks.length).toBeGreaterThanOrEqual(1);
        expect(aboutLinks[0]).toBeInTheDocument();
    });

    it('renders donate link', () => {
        render(Footer);
        // Check for Donate link (desktop nav)
        const donateLinks = screen.getAllByRole('link', { name: /donate/i });
        expect(donateLinks.length).toBeGreaterThanOrEqual(1);
    });

    it('renders copyright notice with current year', () => {
        render(Footer);
        const currentYear = new Date().getFullYear();
        // Multiple copyright notices (desktop + mobile)
        const copyrightElements = screen.getAllByText(new RegExp(`${currentYear}.*gallformers`, 'i'));
        expect(copyrightElements.length).toBeGreaterThanOrEqual(1);
    });

    it('renders license information', () => {
        render(Footer);
        // Multiple CC links (desktop + mobile), use getAllBy
        const ccLinks = screen.getAllByRole('link', { name: /cc by-nc-sa 4.0/i });
        expect(ccLinks.length).toBeGreaterThanOrEqual(1);
    });

    it('has correct href for Donate link (Patreon)', () => {
        render(Footer);
        const donateLinks = screen.getAllByRole('link', { name: /donate/i });
        expect(donateLinks[0]).toHaveAttribute('href', 'https://www.patreon.com/gallformers');
    });

    it('has correct href for Phenology Tool link', () => {
        render(Footer);
        const phenologyLinks = screen.getAllByRole('link', { name: /phenology tool/i });
        expect(phenologyLinks[0]).toHaveAttribute('href', 'https://megachile.shinyapps.io/doycalc/');
    });

    it('opens external links in new tab', () => {
        render(Footer);
        const donateLinks = screen.getAllByRole('link', { name: /donate/i });
        const phenologyLinks = screen.getAllByRole('link', { name: /phenology tool/i });

        expect(donateLinks[0]).toHaveAttribute('target', '_blank');
        expect(donateLinks[0]).toHaveAttribute('rel', 'noopener noreferrer');

        expect(phenologyLinks[0]).toHaveAttribute('target', '_blank');
        expect(phenologyLinks[0]).toHaveAttribute('rel', 'noopener noreferrer');
    });
});
