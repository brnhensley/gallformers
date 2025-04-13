import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import AliasTable from './aliastable';
import { AliasApi, COMMON_NAME, SCIENTIFIC_NAME } from '../libs/api/apitypes';
import { EditableTableProps } from './EditableDataTable';

// Mock the EditableDataTable component
jest.mock('./EditableDataTable', () => {
    return function MockEditableDataTable({ data, update, disabled }: EditableTableProps<AliasApi>) {
        return (
            <div data-testid="editable-data-table">
                <div data-testid="data-length">{data.length}</div>
                <div data-testid="disabled-state">{disabled ? 'disabled' : 'enabled'}</div>
                <button
                    data-testid="add-row"
                    onClick={() => {
                        const newData = [...data, { id: -1, name: '', type: SCIENTIFIC_NAME, description: '' }];
                        update(newData);
                    }}
                    disabled={disabled}
                >
                    Add Row
                </button>
                <button
                    data-testid="update-row"
                    onClick={() => {
                        const updatedData = data.map((item: AliasApi) =>
                            item.id === 1 ? { ...item, name: 'Updated Name' } : item,
                        );
                        update(updatedData);
                    }}
                    disabled={disabled}
                >
                    Update Row
                </button>
                <button
                    data-testid="delete-row"
                    onClick={() => {
                        const filteredData = data.filter((item: AliasApi) => item.id !== 1);
                        update(filteredData);
                    }}
                    disabled={disabled}
                >
                    Delete Row
                </button>
            </div>
        );
    };
});

describe('AliasTable', () => {
    const mockAliases: AliasApi[] = [
        { id: 1, name: 'Test Alias 1', type: COMMON_NAME, description: 'Description 1' },
        { id: 2, name: 'Test Alias 2', type: SCIENTIFIC_NAME, description: 'Description 2' },
    ];

    const mockSetData = jest.fn();

    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('renders the component with the correct title', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);
        expect(screen.getByText('Aliases:')).toBeInTheDocument();
    });

    it('renders the EditableDataTable with the correct props', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const editableTable = screen.getByTestId('editable-data-table');
        expect(editableTable).toBeInTheDocument();

        const dataLength = screen.getByTestId('data-length');
        expect(dataLength).toHaveTextContent('2');

        const disabledState = screen.getByTestId('disabled-state');
        expect(disabledState).toHaveTextContent('enabled');
    });

    it('passes the disabled prop correctly', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} disabled={true} />);

        const disabledState = screen.getByTestId('disabled-state');
        expect(disabledState).toHaveTextContent('disabled');
    });

    it('calls setData when a row is added', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const addButton = screen.getByTestId('add-row');
        fireEvent.click(addButton);

        expect(mockSetData).toHaveBeenCalledTimes(1);
        expect(mockSetData).toHaveBeenCalledWith([...mockAliases, { id: -1, name: '', type: SCIENTIFIC_NAME, description: '' }]);
    });

    it('calls setData when a row is updated', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const updateButton = screen.getByTestId('update-row');
        fireEvent.click(updateButton);

        expect(mockSetData).toHaveBeenCalledTimes(1);
        expect(mockSetData).toHaveBeenCalledWith([
            { id: 1, name: 'Updated Name', type: COMMON_NAME, description: 'Description 1' },
            { id: 2, name: 'Test Alias 2', type: SCIENTIFIC_NAME, description: 'Description 2' },
        ]);
    });

    it('calls setData when a row is deleted', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const deleteButton = screen.getByTestId('delete-row');
        fireEvent.click(deleteButton);

        expect(mockSetData).toHaveBeenCalledTimes(1);
        expect(mockSetData).toHaveBeenCalledWith([
            { id: 2, name: 'Test Alias 2', type: SCIENTIFIC_NAME, description: 'Description 2' },
        ]);
    });

    it('displays the save changes message', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const saveMessage = screen.getByText((content) => content.includes('Changes to the aliases will not be saved'));
        expect(saveMessage).toBeInTheDocument();
        expect(saveMessage.tagName.toLowerCase()).toBe('em');
        expect(saveMessage.parentElement).toHaveClass('small');
        expect(saveMessage.parentElement).toHaveAttribute('aria-live', 'polite');
    });

    it('has proper accessibility attributes', () => {
        render(<AliasTable data={mockAliases} setData={mockSetData} />);

        const tableContainer = screen.getByLabelText('Aliases table');
        expect(tableContainer).toBeInTheDocument();

        const saveMessage = screen.getByText((content) => content.includes('Changes to the aliases will not be saved'));
        expect(saveMessage.parentElement).toHaveAttribute('aria-live', 'polite');
    });
});
