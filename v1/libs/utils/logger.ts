import * as C from 'fp-ts/lib/Console.js';
import { IO } from 'fp-ts/lib/IO.js';
import * as L from 'logging-ts/lib/IO.js';
import pino from 'pino';

// Detect if we're running in the browser or Node.js
const isBrowser = typeof window !== 'undefined';

// Helper to safely extract message from object
const extractMessage = (obj: unknown): string => {
    if (typeof obj === 'object' && obj !== null && 'message' in obj) {
        const message = (obj as Record<string, unknown>).message;
        return typeof message === 'string' ? message : '';
    }
    return '';
};

// Browser-compatible logger
const browserLogger = {
    info: (obj: unknown, msg?: string) => {
        const message = msg || extractMessage(obj);
        console.log(`[INFO] ${message}`, obj);
    },
    warn: (obj: unknown, msg?: string) => {
        const message = msg || extractMessage(obj);
        console.warn(`[WARN] ${message}`, obj);
    },
    error: (obj: unknown, msg?: string) => {
        const message = msg || extractMessage(obj);
        console.error(`[ERROR] ${message}`, obj);
    },
    debug: (obj: unknown, msg?: string) => {
        const message = msg || extractMessage(obj);
        console.debug(`[DEBUG] ${message}`, obj);
    },
};

// Server-side Pino logger
const pinoLogger = pino({
    transport: {
        target: 'pino-pretty',
        options: {
            colorize: true,
        },
    },
});

// Export the appropriate logger based on environment
export const logger = isBrowser ? browserLogger : pinoLogger;

// WIP stuff below here:
type Level = 'Debug' | 'Info' | 'Warning' | 'Error';

interface Entry {
    message: string;
    time: Date;
    level: Level;
}

function showEntry(entry: Entry): string {
    return `[${entry.level}] ${entry.time.toLocaleString()} ${entry.message}`;
}

function getLoggerEntry(prefix: string): L.LoggerIO<Entry> {
    return (entry) => C.log(`${prefix}: ${showEntry(entry)}`);
}

const debugLogger = L.filter(getLoggerEntry('debug.log'), (e) => e.level === 'Debug');
const productionLogger = L.filter(getLoggerEntry('production.log'), (e) => e.level !== 'Debug');
export const flogger = L.getMonoid<Entry>().concat(debugLogger, productionLogger);

export const info =
    (message: string) =>
    (time: Date): IO<void> =>
        flogger({ message, time, level: 'Info' });
export const debug =
    (message: string) =>
    (time: Date): IO<void> =>
        flogger({ message, time, level: 'Debug' });
