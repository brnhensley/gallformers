import { Prisma, PrismaPromise } from '@prisma/client';
import * as TE from 'fp-ts/lib/TaskEither';
import { pipe } from 'fp-ts/lib/function';
import { GallApi, GallHostUpdateFields, SpeciesWithPlaces, taxonCodeAsStringToValue } from '../api/apitypes';
import { ExtractTFromPromise } from '../utils/types';
import { handleError } from '../utils/util';
import db from './db';
import { gallByIdAsO } from './gall';

const toInsertStatement = (gallid: number, hostids: number[]): PrismaPromise<number> => {
    // Build parameterized VALUES for batch insert using Prisma.join
    const values = hostids.map((h) => Prisma.sql`(NULL, ${gallid}, ${h})`);
    return db.$executeRaw`INSERT INTO host (id, gall_species_id, host_species_id) VALUES ${Prisma.join(values)}`;
};

export const updateGallHosts = (gallhost: GallHostUpdateFields): TE.TaskEither<Error, GallApi> => {
    const doTx = () => () => {
        const deletes = db.$executeRaw`DELETE FROM host WHERE gall_species_id = ${gallhost.gall}`;
        const hosts = [...new Set([...gallhost.hosts])];

        const steps: PrismaPromise<number>[] = [deletes];
        if (hosts.length > 0) steps.push(toInsertStatement(gallhost.gall, hosts));

        // handle the gall range - for now hack using the existing table
        steps.push(db.$executeRaw`DELETE FROM speciesplace WHERE species_id = ${gallhost.gall}`);
        gallhost.rangeExclusions.forEach((place) =>
            steps.push(db.$executeRaw`INSERT INTO speciesplace (species_id, place_id) VALUES (${gallhost.gall}, ${place.id})`),
        );

        return db.$transaction(steps);
    };

    return pipe(
        TE.tryCatch(doTx(), handleError),
        TE.chain(() => gallByIdAsO(gallhost.gall)),
        TE.map(TE.fromOption(() => new Error('Failed to retrieve gall after GallHost update.'))),
        TE.flatten,
    );
};

export const hostsByGallId = (gallid: number): TE.TaskEither<Error, SpeciesWithPlaces[]> => {
    const lookupHosts = () =>
        db.host.findMany({
            include: { hostspecies: { include: { places: { include: { place: true } } } } },
            where: { gall_species_id: gallid },
        });

    const toSpeciesApi = (hosts: ExtractTFromPromise<ReturnType<typeof lookupHosts>>): SpeciesWithPlaces[] =>
        hosts.flatMap((h) =>
            h.hostspecies != undefined
                ? {
                      ...h.hostspecies,
                      taxoncode: taxonCodeAsStringToValue(h.hostspecies.taxoncode),
                      places: h.hostspecies.places.map((p) => p.place),
                  }
                : [],
        );

    // eslint-disable-next-line prettier/prettier
    return pipe(
        TE.tryCatch(lookupHosts, handleError),
        TE.map(toSpeciesApi),
    );
};
