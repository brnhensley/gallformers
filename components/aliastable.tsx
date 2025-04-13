import React from 'react';
import { AliasApi, COMMON_NAME, EmptyAlias, SCIENTIFIC_NAME } from '../libs/api/apitypes';
import { TABLE_CUSTOM_STYLES } from '../libs/utils/DataTableConstants';
import EditableDataTable, { EditableTableColumn } from './EditableDataTable';

export type AliasTableProps = {
    data: AliasApi[];
    setData: (d: AliasApi[]) => void;
    disabled?: boolean;
};

/**
 * A component that renders an editable table of aliases
 *
 * This component allows users to view, add, edit, and delete aliases.
 * Changes are not saved until the parent form is submitted.
 *
 * @param data - Array of alias data to display
 * @param setData - Callback function to update the alias data
 * @param disabled - Optional flag to disable editing of the table
 * @returns JSX.Element
 */
const AliasTable = ({ data, setData, disabled }: AliasTableProps): JSX.Element => {
    const columns: EditableTableColumn<AliasApi>[] = [
        {
            name: 'Alias Name',
            selector: (row: AliasApi) => row.name,
            sortable: true,
            wrap: true,
            maxWidth: '300px',
            editKey: 'name',
        },
        {
            name: 'Type',
            selector: (row: AliasApi) => row.type,
            sortable: true,
            maxWidth: '150px',
            editKey: 'type',
            editor: {
                type: 'select',
                options: [
                    { value: COMMON_NAME, label: COMMON_NAME },
                    { value: SCIENTIFIC_NAME, label: SCIENTIFIC_NAME },
                ],
            },
        },
        {
            name: 'Description',
            selector: (row: AliasApi) => row.description,
            wrap: true,
            editKey: 'description',
        },
    ];

    return (
        <div aria-label="Aliases table">
            <h3>Aliases:</h3>
            <EditableDataTable
                keyField={'id'}
                data={data}
                columns={columns}
                striped
                responsive={false}
                defaultSortFieldId="name"
                customStyles={TABLE_CUSTOM_STYLES}
                createEmpty={() => EmptyAlias}
                update={setData}
                disabled={disabled}
            />
            <p className="small" aria-live="polite">
                <em>
                    Changes to the aliases will not be saved until you save the whole form by clicking &lsquo;Save Changes&rsquo;
                    below.
                </em>
            </p>
        </div>
    );
};

export default AliasTable;
