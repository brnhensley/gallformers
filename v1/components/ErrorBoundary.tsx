import React, { Component, ErrorInfo, ReactNode } from 'react';
import { Alert, Button, Card, Col, Container, Row } from 'react-bootstrap';
import { logger } from '@/libs/utils/logger';

interface Props {
    children: ReactNode;
}

interface State {
    hasError: boolean;
    error: Error | null;
    errorInfo: ErrorInfo | null;
}

class ErrorBoundary extends Component<Props, State> {
    constructor(props: Props) {
        super(props);
        this.state = {
            hasError: false,
            error: null,
            errorInfo: null,
        };
    }

    static getDerivedStateFromError(): Partial<State> {
        // Update state so the next render will show the fallback UI
        return { hasError: true };
    }

    componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
        // Log with clear formatting to help identify the source
        console.group('🔴 ERROR CAUGHT BY ERROR BOUNDARY');
        console.error('Error:', error.message);
        console.error('Error stack:', error.stack);
        console.group('Component Stack (where error occurred):');
        console.log(errorInfo.componentStack);
        console.groupEnd();
        console.log('URL:', window.location.href);
        console.groupEnd();

        // Also log via Pino for server-side
        logger.error({
            message: error.message,
            stack: error.stack,
            componentStack: errorInfo.componentStack,
            location: window.location.href,
        });

        // Update state with error details
        this.setState({
            error,
            errorInfo,
        });
    }

    handleReset = (): void => {
        this.setState({
            hasError: false,
            error: null,
            errorInfo: null,
        });
    };

    render(): ReactNode {
        if (this.state.hasError) {
            const isDev = process.env.NODE_ENV === 'development';

            return (
                <Container className="my-5">
                    <Row>
                        <Col>
                            <Alert variant="danger">
                                <Alert.Heading>Something went wrong</Alert.Heading>
                                <p>
                                    An unexpected error occurred. Please try refreshing the page. If the problem persists, please
                                    report this issue on{' '}
                                    <a href="https://github.com/jeffdc/gallformers/issues/new" target="_blank" rel="noreferrer">
                                        Github
                                    </a>
                                    .
                                </p>
                                <hr />
                                <div className="d-flex gap-2">
                                    <Button variant="outline-danger" onClick={this.handleReset}>
                                        Try Again
                                    </Button>
                                    <Button variant="outline-secondary" onClick={() => window.location.reload()}>
                                        Refresh Page
                                    </Button>
                                </div>
                            </Alert>

                            {isDev && this.state.error && (
                                <Card className="mt-3" border="danger">
                                    <Card.Header className="bg-danger text-white">
                                        <strong>Development Error Details</strong>
                                    </Card.Header>
                                    <Card.Body>
                                        <Card.Title className="text-danger">{this.state.error.toString()}</Card.Title>
                                        {this.state.error.stack && (
                                            <details className="mt-3">
                                                <summary style={{ cursor: 'pointer' }}>
                                                    <strong>Stack Trace</strong>
                                                </summary>
                                                <pre className="mt-2 p-3 bg-light border rounded" style={{ fontSize: '0.85em' }}>
                                                    {this.state.error.stack}
                                                </pre>
                                            </details>
                                        )}
                                        {this.state.errorInfo && (
                                            <details className="mt-3">
                                                <summary style={{ cursor: 'pointer' }}>
                                                    <strong>Component Stack</strong>
                                                </summary>
                                                <pre className="mt-2 p-3 bg-light border rounded" style={{ fontSize: '0.85em' }}>
                                                    {this.state.errorInfo.componentStack}
                                                </pre>
                                            </details>
                                        )}
                                        <details className="mt-3">
                                            <summary style={{ cursor: 'pointer' }}>
                                                <strong>Page Information</strong>
                                            </summary>
                                            <pre className="mt-2 p-3 bg-light border rounded" style={{ fontSize: '0.85em' }}>
                                                {`URL: ${window.location.href}\nTimestamp: ${new Date().toISOString()}`}
                                            </pre>
                                        </details>
                                    </Card.Body>
                                </Card>
                            )}
                        </Col>
                    </Row>
                </Container>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary;
