import { useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import toast, { Toaster } from 'react-hot-toast';
import { Genus } from '../libs/api/apitypes';

export type RenameGenusEvent = {
    old: Genus;
    newName: string;
};

type Props = {
    genus: Genus | undefined;
    showModal: boolean;
    setShowModal: (showModal: boolean) => void;
    nameExistsCallback: (name: string) => Promise<boolean>;
    renameCallback: (e: RenameGenusEvent) => Promise<void>;
};

const RenameGenus = ({ genus, showModal, setShowModal, renameCallback, nameExistsCallback }: Props): JSX.Element => {
    const [value, setValue] = useState(genus?.name ?? '');
    const [dirty, setDirty] = useState(false);

    const handleClose = () => {
        setShowModal(false);
        setDirty(false);
    };

    return (
        <>
            <div>
                <Toaster />
            </div>
            <Modal show={showModal} onHide={handleClose} size="lg">
                <Modal.Header closeButton>
                    <Modal.Title>{`Rename Genus: ${genus?.name ?? ''}`}</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    {genus == undefined ? (
                        <div className="text-danger">No genus selected. Please select exactly one genus to rename.</div>
                    ) : (
                        <>
                            <label className="form-label">New Name:</label>
                            <input
                                className="form-control"
                                type="text"
                                defaultValue={genus.name}
                                onChange={(e) => {
                                    setDirty(true);
                                    setValue(e.currentTarget.value);
                                }}
                            />
                            <div className="mt-2 small text-muted">
                                Enter the new name for this genus. The name must be unique and cannot be empty.
                            </div>
                        </>
                    )}
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={handleClose}>
                        Cancel
                    </Button>
                    <Button
                        variant="primary"
                        type="submit"
                        disabled={!dirty || genus == undefined || value === ''}
                        onClick={() => {
                            if (genus == undefined) {
                                toast.error('No genus selected.');
                                return;
                            }
                            if (value === '') {
                                toast.error('The name must not be empty.');
                                return;
                            }
                            if (value === genus.name) {
                                toast.error('The new name is the same as the current name.');
                                return;
                            }
                            nameExistsCallback(value)
                                .then((exists) => {
                                    if (exists) {
                                        toast.error('That name is already in use by another genus.');
                                    } else {
                                        void renameCallback({
                                            old: genus,
                                            newName: value,
                                        });
                                        handleClose();
                                    }
                                })
                                .catch((error) => {
                                    toast.error('An error occurred while checking the name.');
                                    console.error(error);
                                });
                        }}
                    >
                        Save Changes
                    </Button>
                </Modal.Footer>
            </Modal>
        </>
    );
};

export default RenameGenus;
