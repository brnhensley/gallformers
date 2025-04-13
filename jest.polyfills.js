/**
 * Polyfills for Jest test environment
 */

// Polyfill for setImmediate
global.setImmediate = (callback, ...args) => setTimeout(() => callback(...args), 0);

// Add support for React's act() function
global.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
};

// Mock PrismaClient for browser environment
jest.mock('@prisma/client', () => ({
    PrismaClient: jest.fn().mockImplementation(() => ({
        $executeRaw: jest.fn().mockResolvedValue(null),
        $queryRaw: jest.fn().mockResolvedValue(null),
    })),
})); 