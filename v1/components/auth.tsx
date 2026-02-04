import { signIn, useSession } from 'next-auth/react';
import React, { useEffect, useState } from 'react';
import { Alert } from 'react-bootstrap';

export const superAdmins = ['jeff', 'adamjameskranz'];

const Auth = ({ superAdmin, children }: { superAdmin?: boolean; children: JSX.Element }): JSX.Element => {
    const { data: session, status } = useSession();
    const [readonlyMode, setReadonlyMode] = useState<boolean | null>(null);

    useEffect(() => {
        fetch('/api/config')
            .then((res) => res.json())
            .then((data: { readonlyMode: boolean }) => setReadonlyMode(data.readonlyMode))
            .catch(() => setReadonlyMode(false));
    }, []);

    // Still loading config
    if (readonlyMode === null) {
        return <p className="m-3 p-3">Hold tight. Working on vetting you...</p>;
    }

    if (readonlyMode) {
        return (
            <div className="m-3 p-3">
                <Alert variant="warning">
                    <Alert.Heading>Admin Temporarily Disabled</Alert.Heading>
                    <p>
                        Gallformers V2 is launching soon! To ensure a smooth migration, I have temporarily paused data edits from{' '}
                        <strong>Wednesday, February 4th at 8 am ET</strong> through no later than{' '}
                        <strong>Friday, February 6th at 10 am ET</strong>. It is very likely that it will take a lot less time
                        than this, but I am building a buffer in case I run into any isses.
                    </p>
                    <p>The main site remains fully available for browsing—only admin functions are paused.</p>
                    <p>After the freeze, V2 will be live with a brand new admin interface and other improvements!</p>
                    <hr />
                    <p>Thanks for your patience,</p>
                    <p>Jeff</p>
                </Alert>
            </div>
        );
    }

    if (status === 'loading') {
        return <p className="m-3 p-3">Hold tight. Working on vetting you...</p>;
    }

    if (!session) {
        return (
            <div className="m-3 p-3">
                <p>
                    These are not the droids you are looking for. If you think that you really do want some droids, then login
                    first.
                </p>
                {/* eslint-disable-next-line @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-assignment */}
                <button onClick={signIn as any}>Log In</button>
            </div>
        );
    }

    if (!!superAdmin && session.user && session.user.name && !superAdmins.includes(session.user.name)) {
        return (
            <div className="m-3 p-3">
                <p>Hmmm. You should probably not be here.</p>
            </div>
        );
    }

    return children;
};

export default Auth;
