import '@testing-library/jest-dom';
import { configure } from '@testing-library/react';
import React from 'react';
import type { ReactNode } from 'react';

// Configure React Testing Library
configure({
    asyncUtilTimeout: 100, // Increased timeout for async operations
});

// Enable fake timers
beforeAll(() => {
    jest.useFakeTimers();
});

afterAll(() => {
    jest.useRealTimers();
});

// Mock next/router
jest.mock('next/router', () => ({
    useRouter: () => ({
        route: '/',
        pathname: '',
        query: {},
        asPath: '',
        push: jest.fn(),
        replace: jest.fn(),
        reload: jest.fn(),
        back: jest.fn(),
        prefetch: jest.fn(),
        beforePopState: jest.fn(),
        events: {
            on: jest.fn(),
            off: jest.fn(),
            emit: jest.fn(),
        },
        isFallback: false,
    }),
}));

// Mock next/head
jest.mock('next/head', () => {
    const MockHead = ({ children }: { children: ReactNode }): JSX.Element => {
        return React.createElement(React.Fragment, null, children);
    };
    MockHead.displayName = 'MockHead';
    return {
        __esModule: true,
        default: MockHead,
    };
});

// Configure global test environment
global.ResizeObserver = jest.fn().mockImplementation(() => ({
    observe: jest.fn(),
    unobserve: jest.fn(),
    disconnect: jest.fn(),
}));

// Suppress React 18 console warnings about act()
const originalError = console.error;
beforeAll(() => {
    console.error = (...args: unknown[]) => {
        if (typeof args[0] === 'string' && /Warning.*not wrapped in act/.test(args[0])) {
            return;
        }
        originalError.call(console, ...args);
    };
});

afterAll(() => {
    console.error = originalError;
});
