import { memo, useEffect, useState } from 'react';
import markdownStyles from './markdown-styles.module.css';

type Props = {
    content: string;
    className?: string;
};

const PostBody = memo(({ content, className = '' }: Props) => {
    const [sanitizedContent, setSanitizedContent] = useState(content);

    useEffect(() => {
        // Only run on client side
        if (typeof window !== 'undefined') {
            // Dynamically import DOMPurify
            void import('dompurify').then((DOMPurify) => {
                setSanitizedContent(DOMPurify.default.sanitize(content));
            });
        }
    }, [content]);

    return (
        <div
            className={`${markdownStyles['markdown']} ${className}`}
            dangerouslySetInnerHTML={{ __html: sanitizedContent }}
            role="article"
            aria-label="Post content"
        />
    );
});

PostBody.displayName = 'PostBody';

export default PostBody;
