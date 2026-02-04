import type { NextApiRequest, NextApiResponse } from 'next';

type ConfigResponse = {
    readonlyMode: boolean;
};

export default function handler(req: NextApiRequest, res: NextApiResponse<ConfigResponse>) {
    res.status(200).json({
        readonlyMode: process.env.READONLY_MODE === 'true',
    });
}
