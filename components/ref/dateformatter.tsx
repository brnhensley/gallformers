import { parseISO, format, Locale } from 'date-fns';
import { useMemo } from 'react';

type Props = {
    dateString: string;
    locale?: Locale;
    fallback?: string;
};

const DateFormatter = ({ dateString, locale, fallback = 'Invalid date' }: Props) => {
    const formattedDate = useMemo(() => {
        try {
            const date = parseISO(dateString);
            if (isNaN(date.getTime())) {
                return fallback;
            }
            return format(date, 'LLLL d, yyyy', { locale });
        } catch {
            return fallback;
        }
    }, [dateString, locale, fallback]);

    return <time dateTime={dateString}>{formattedDate}</time>;
};

export default DateFormatter;
