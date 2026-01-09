<script lang="ts">
	import Button from '../forms/Button.svelte';

	interface Column<T> {
		key: string;
		label: string;
		sortable?: boolean;
		render?: (row: T) => string;
	}

	let {
		data,
		columns,
		sortBy = $bindable(null),
		sortDir = $bindable('asc'),
		onsort,
		page = 1,
		pageSize = 25,
		totalCount = 0,
		onpagechange
	}: {
		data: unknown[];
		columns: Column<unknown>[];
		sortBy?: string | null;
		sortDir?: 'asc' | 'desc';
		onsort?: (key: string) => void;
		page?: number;
		pageSize?: number;
		totalCount?: number;
		onpagechange?: (page: number) => void;
	} = $props();

	// Pagination calculations
	let totalPages = $derived(Math.ceil(totalCount / pageSize));
	let showPagination = $derived(totalCount > pageSize);
	let startItem = $derived((page - 1) * pageSize + 1);
	let endItem = $derived(Math.min(page * pageSize, totalCount));

	function handleSort(key: string) {
		if (!onsort) return;
		if (sortBy === key) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = key;
			sortDir = 'asc';
		}
		onsort(key);
	}

	function getValue(row: unknown, col: Column<unknown>): string {
		if (col.render) {
			return col.render(row);
		}
		const record = row as Record<string, unknown>;
		const value = record[col.key];
		return value != null ? String(value) : '';
	}

	function goToPage(newPage: number) {
		if (onpagechange && newPage >= 1 && newPage <= totalPages) {
			onpagechange(newPage);
		}
	}
</script>

<div class="overflow-x-auto">
	<table class="min-w-full divide-y divide-gray-200">
		<thead class="bg-gray-50">
			<tr>
				{#each columns as col}
					<th
						class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider
                   {col.sortable ? 'cursor-pointer hover:bg-gray-100' : ''}"
						onclick={() => col.sortable && handleSort(col.key)}
					>
						{col.label}
						{#if col.sortable && sortBy === col.key}
							<span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
						{/if}
					</th>
				{/each}
			</tr>
		</thead>
		<tbody class="bg-white divide-y divide-gray-200">
			{#each data as row}
				<tr class="hover:bg-gray-50">
					{#each columns as col}
						<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
							{getValue(row, col)}
						</td>
					{/each}
				</tr>
			{/each}
		</tbody>
	</table>
</div>

{#if showPagination}
	<div class="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200">
		<div class="text-sm text-gray-700">
			Showing {startItem} to {endItem} of {totalCount} results
		</div>
		<div class="flex items-center gap-2">
			<Button variant="secondary" disabled={page === 1} onclick={() => goToPage(page - 1)}>
				Previous
			</Button>
			<span class="px-3 text-sm text-gray-700"> Page {page} of {totalPages} </span>
			<Button variant="secondary" disabled={page === totalPages} onclick={() => goToPage(page + 1)}>
				Next
			</Button>
		</div>
	</div>
{/if}
