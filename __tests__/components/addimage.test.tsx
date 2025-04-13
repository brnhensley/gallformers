import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useSession } from 'next-auth/react';
import AddImage from '../../components/addimage';
import axios from 'axios';
import { toast } from 'react-hot-toast';

// Mock next-auth
jest.mock('next-auth/react', () => ({
    useSession: jest.fn(),
}));

// Mock axios
jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

// Mock toast
jest.mock('react-hot-toast', () => ({
    toast: {
        error: jest.fn(),
        success: jest.fn(),
    },
}));

describe('AddImage Component', () => {
    const mockOnChange = jest.fn();
    const mockId = 123;
    const mockUploadUrl = 'https://example.com/upload-url';
    const mockImageResponse = [
        {
            id: 1,
            path: 'test/path.jpg',
            uploader: 'Test User',
            speciesid: mockId,
        },
    ];

    // Mock session data
    const mockSession = {
        data: {
            user: {
                name: 'Test User',
            },
        },
        status: 'authenticated',
    };

    beforeEach(() => {
        jest.clearAllMocks();
        (useSession as jest.Mock).mockReturnValue(mockSession);

        // Setup default fetch mock
        global.fetch = jest.fn().mockImplementation((url) => {
            if (url.includes('uploadurl')) {
                return Promise.resolve({
                    text: () => Promise.resolve(mockUploadUrl),
                });
            }
            if (url.includes('upsert')) {
                return Promise.resolve({
                    json: () => Promise.resolve(mockImageResponse),
                    ok: true,
                });
            }
            return Promise.reject(new Error('Unhandled fetch call'));
        });
    });

    it('renders upload button when user is authenticated', () => {
        render(<AddImage id={mockId} onChange={mockOnChange} />);
        expect(screen.getByText('Upload New Image(s)')).toBeInTheDocument();
    });

    it('does not render when user is not authenticated', () => {
        (useSession as jest.Mock).mockReturnValue({ data: null, status: 'unauthenticated' });
        const { container } = render(<AddImage id={mockId} onChange={mockOnChange} />);
        expect(container).toBeEmptyDOMElement();
    });

    it('shows error when too many files are selected', async () => {
        render(<AddImage id={mockId} onChange={mockOnChange} />);

        const fileInput = screen.getByLabelText('Upload New Image(s)');
        const files = Array(5)
            .fill(null)
            .map((_, i) => new File(['test'], `test${i}.jpg`, { type: 'image/jpeg' }));

        Object.defineProperty(fileInput, 'files', {
            value: files,
        });

        fireEvent.change(fileInput);

        expect(toast.error).toHaveBeenCalledWith('You can currently only upload 4 or fewer images at one time.');
    });

    it('handles successful file upload', async () => {
        // Mock successful axios upload
        mockedAxios.put.mockResolvedValueOnce({});

        render(<AddImage id={mockId} onChange={mockOnChange} />);

        const fileInput = screen.getByLabelText('Upload New Image(s)');
        const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });

        Object.defineProperty(fileInput, 'files', {
            value: [file],
        });

        fireEvent.change(fileInput);

        // Wait for the progress bar to appear
        await waitFor(() => {
            expect(screen.getByRole('progressbar')).toBeInTheDocument();
        });

        // Wait for the onChange callback
        await waitFor(
            () => {
                expect(mockOnChange).toHaveBeenCalledWith(mockImageResponse);
            },
            { timeout: 15000 },
        ); // Increased timeout due to CDN delay simulation
    });

    it('handles upload error', async () => {
        // Mock axios error with response data
        const errorMessage = 'Network error';
        const axiosError = new Error(errorMessage) as any;
        axiosError.isAxiosError = true;
        axiosError.response = {
            data: { message: errorMessage },
            status: 500,
            headers: {},
        };
        mockedAxios.put.mockRejectedValueOnce(axiosError);

        render(<AddImage id={mockId} onChange={mockOnChange} />);

        const fileInput = screen.getByLabelText('Upload New Image(s)');
        const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });

        Object.defineProperty(fileInput, 'files', {
            value: [file],
        });

        fireEvent.change(fileInput);

        // Wait for the error alert to appear
        await waitFor(
            () => {
                const alert = screen.getByRole('alert');
                expect(alert).toBeInTheDocument();
                const errorText = JSON.stringify(new Error(`Upload failed: ${errorMessage}`));
                expect(alert).toHaveTextContent(errorText);
            },
            { timeout: 5000 },
        );
    });

    it('shows progress bar during upload', async () => {
        // Mock axios with progress
        mockedAxios.put.mockImplementationOnce((url, data, config) => {
            if (config?.onUploadProgress) {
                config.onUploadProgress({ loaded: 50, total: 100 } as any);
            }
            return Promise.resolve({} as any);
        });

        render(<AddImage id={mockId} onChange={mockOnChange} />);

        const fileInput = screen.getByLabelText('Upload New Image(s)');
        const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });

        Object.defineProperty(fileInput, 'files', {
            value: [file],
        });

        fireEvent.change(fileInput);

        await waitFor(() => {
            const progressBar = screen.getByRole('progressbar');
            expect(progressBar).toBeInTheDocument();
            expect(progressBar).toHaveAttribute('aria-valuenow', '30'); // 50% of 60% (UPLOAD_MAX_PERCENT)
        });
    });
});
