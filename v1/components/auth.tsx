import { signIn, useSession } from 'next-auth/react';
import React from 'react';
import { Alert } from 'react-bootstrap';

export const superAdmins = ['jeff', 'adamjameskranz'];

const READONLY_MODE = process.env.NEXT_PUBLIC_READONLY_MODE === 'true';

const Auth = ({ superAdmin, children }: { superAdmin?: boolean; children: JSX.Element }): JSX.Element => {
    const { data: session, status } = useSession();

    if (READONLY_MODE) {
        return (
            <div className="m-3 p-3">
                <Alert variant="warning">
                    <Alert.Heading>Admin Temporarily Disabled</Alert.Heading>
                    <p>
                        Gallformers V2 is launching soon! To ensure a smooth migration, we&apos;ve temporarily paused data edits
                        from <strong>Wednesday, February 4th at 10am</strong> through{' '}
                        <strong>Friday, February 6th at 10am</strong> (Eastern Time).
                    </p>
                    <p>The main site remains fully available for browsing—only admin functions are paused.</p>
                    <hr />
                    <p className="mb-0">
                        After the freeze, V2 will be live at{' '}
                        <Alert.Link href="https://gallformers.org">gallformers.org</Alert.Link> with a brand new admin interface.
                        Thanks for your patience!
                    </p>
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
