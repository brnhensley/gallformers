import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Table from './Table.svelte';

const sampleData = [
	{ id: 1, name: 'Oak Apple Gall', host: 'White Oak' },
	{ id: 2, name: 'Wool Sower Gall', host: 'White Oak' },
	{ id: 3, name: 'Mossy Rose Gall', host: 'Wild Rose' }
];

const columns = [
	{ key: 'name', label: 'Name', sortable: true },
	{ key: 'host', label: 'Host', sortable: true },
	{ key: 'id', label: 'ID' }
];

describe('Table', () => {
	it('renders column headers', () => {
		render(Table, {
			props: {
				data: sampleData,
				columns
			}
		});

		expect(screen.getByText('Name')).toBeInTheDocument();
		expect(screen.getByText('Host')).toBeInTheDocument();
		expect(screen.getByText('ID')).toBeInTheDocument();
	});

	it('renders data rows', () => {
		render(Table, {
			props: {
				data: sampleData,
				columns
			}
		});

		expect(screen.getByText('Oak Apple Gall')).toBeInTheDocument();
		expect(screen.getByText('Wool Sower Gall')).toBeInTheDocument();
		expect(screen.getByText('Mossy Rose Gall')).toBeInTheDocument();
	});

	it('renders data using custom render function', () => {
		const columnsWithRender = [
			{
				key: 'name',
				label: 'Species',
				render: (row) => `Species: ${row.name}`
			}
		];

		render(Table, {
			props: {
				data: sampleData,
				columns: columnsWithRender
			}
		});

		expect(screen.getByText('Species: Oak Apple Gall')).toBeInTheDocument();
	});

	it('shows sort indicator for sorted column', () => {
		render(Table, {
			props: {
				data: sampleData,
				columns,
				sortBy: 'name',
				sortDir: 'asc'
			}
		});

		const nameHeader = screen.getByText('Name');
		expect(nameHeader.parentElement).toHaveTextContent('↑');
	});

	it('shows descending sort indicator', () => {
		render(Table, {
			props: {
				data: sampleData,
				columns,
				sortBy: 'name',
				sortDir: 'desc'
			}
		});

		const nameHeader = screen.getByText('Name');
		expect(nameHeader.parentElement).toHaveTextContent('↓');
	});

	it('calls onsort when sortable column header clicked', async () => {
		const onsort = vi.fn();
		render(Table, {
			props: {
				data: sampleData,
				columns,
				onsort
			}
		});

		const nameHeader = screen.getByText('Name').closest('th');
		await fireEvent.click(nameHeader);

		expect(onsort).toHaveBeenCalledWith('name');
	});

	it('does not call onsort when non-sortable column clicked', async () => {
		const onsort = vi.fn();
		render(Table, {
			props: {
				data: sampleData,
				columns,
				onsort
			}
		});

		const idHeader = screen.getByText('ID').closest('th');
		await fireEvent.click(idHeader);

		expect(onsort).not.toHaveBeenCalled();
	});

	it('toggles sort direction on repeated click', async () => {
		const onsort = vi.fn();
		const { rerender } = render(Table, {
			props: {
				data: sampleData,
				columns,
				sortBy: 'name',
				sortDir: 'asc',
				onsort
			}
		});

		const nameHeader = screen.getByText('Name').closest('th');
		await fireEvent.click(nameHeader);

		// After clicking, sortDir should have toggled
		expect(onsort).toHaveBeenCalledWith('name');
	});

	it('has hover class on rows', () => {
		const { container } = render(Table, {
			props: {
				data: sampleData,
				columns
			}
		});

		const rows = container.querySelectorAll('tbody tr');
		rows.forEach((row) => {
			expect(row).toHaveClass('hover:bg-gray-50');
		});
	});

	describe('pagination', () => {
		it('hides pagination when totalCount <= pageSize', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 1,
					pageSize: 25,
					totalCount: 3
				}
			});

			expect(screen.queryByText(/Showing/)).not.toBeInTheDocument();
			expect(screen.queryByRole('button', { name: 'Previous' })).not.toBeInTheDocument();
		});

		it('shows pagination when totalCount > pageSize', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 1,
					pageSize: 25,
					totalCount: 100
				}
			});

			expect(screen.getByText('Showing 1 to 25 of 100 results')).toBeInTheDocument();
			expect(screen.getByRole('button', { name: 'Previous' })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: 'Next' })).toBeInTheDocument();
		});

		it('shows correct page info text', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 2,
					pageSize: 25,
					totalCount: 100
				}
			});

			expect(screen.getByText('Showing 26 to 50 of 100 results')).toBeInTheDocument();
			expect(screen.getByText('Page 2 of 4')).toBeInTheDocument();
		});

		it('shows correct end item on last page', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 4,
					pageSize: 25,
					totalCount: 90
				}
			});

			expect(screen.getByText('Showing 76 to 90 of 90 results')).toBeInTheDocument();
		});

		it('disables Previous button on first page', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 1,
					pageSize: 25,
					totalCount: 100
				}
			});

			const prevBtn = screen.getByRole('button', { name: 'Previous' });
			expect(prevBtn).toBeDisabled();
		});

		it('disables Next button on last page', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 4,
					pageSize: 25,
					totalCount: 100
				}
			});

			const nextBtn = screen.getByRole('button', { name: 'Next' });
			expect(nextBtn).toBeDisabled();
		});

		it('enables both buttons on middle page', () => {
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 2,
					pageSize: 25,
					totalCount: 100
				}
			});

			const prevBtn = screen.getByRole('button', { name: 'Previous' });
			const nextBtn = screen.getByRole('button', { name: 'Next' });
			expect(prevBtn).not.toBeDisabled();
			expect(nextBtn).not.toBeDisabled();
		});

		it('calls onpagechange with previous page when Previous clicked', async () => {
			const onpagechange = vi.fn();
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 2,
					pageSize: 25,
					totalCount: 100,
					onpagechange
				}
			});

			const prevBtn = screen.getByRole('button', { name: 'Previous' });
			await fireEvent.click(prevBtn);

			expect(onpagechange).toHaveBeenCalledWith(1);
		});

		it('calls onpagechange with next page when Next clicked', async () => {
			const onpagechange = vi.fn();
			render(Table, {
				props: {
					data: sampleData,
					columns,
					page: 2,
					pageSize: 25,
					totalCount: 100,
					onpagechange
				}
			});

			const nextBtn = screen.getByRole('button', { name: 'Next' });
			await fireEvent.click(nextBtn);

			expect(onpagechange).toHaveBeenCalledWith(3);
		});
	});
});
