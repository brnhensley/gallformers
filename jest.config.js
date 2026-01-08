import nextJest from 'next/jest.js';
const createJestConfig = nextJest({
    dir: './',
});
const customJestConfig = {
    // Automatically clear mock calls and instances between every test
    clearMocks: true,
    // Ignore v2 directory (separate test setup)
    testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/v2/'],
    // The directory where Jest should output its coverage files
    coverageDirectory: '.coverage',
    // A list of paths to modules that run some code to configure or set up the testing framework before each test
    setupFilesAfterEnv: ['./jest.setup.ts'],
    moduleNameMapper: {
        '\\.(scss|sass|css)$': 'identity-obj-proxy',
        '^@/(.*)$': '<rootDir>/$1',
    },
    moduleDirectories: ['node_modules', '<rootDir>/'],
    testEnvironment: 'jest-environment-jsdom',
    setupFiles: ['<rootDir>/jest.polyfills.js'],
};
export default createJestConfig(customJestConfig);
